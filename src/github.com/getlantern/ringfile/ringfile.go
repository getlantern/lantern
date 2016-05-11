// Package ringfile provides a file-backed ring buffer that stores arbitrary
// bytes. The data is stored in 3 files:
//
// _idx - contains indexing information for the items stored in the buffer
// _1 and _2 - the actual data files. Two files are used to allow wrapping the
//             buffer without overwriting old data.
package ringfile

import (
	"encoding/binary"
	"fmt"
	"io"
	"os"

	"github.com/getlantern/golog"
)

const (
	int8Size        = 1
	int32Size       = 4
	int64Size       = 8
	filePointerSize = int8Size*1 + int64Size*2
	headerSize      = int32Size*3 + filePointerSize
)

var (
	log = golog.LoggerFor("ringfile")

	endianness = binary.BigEndian
)

// Buffer is a file-backed ring buffer.
type Buffer interface {
	io.WriteCloser

	// AllFromOldest iterates over all values in the Buffer starting at the
	// oldest.
	AllFromOldest(onValue func(io.Reader) error) error
}

type buffer struct {
	capacity    int
	size        int
	nextIdx     int
	nextPointer filepointer
	pointers    []filepointer
	startOfData int64
	idxFile     *os.File
	dataFiles   []*os.File
}

type filepointer struct {
	file   int
	offset int64
	length int64
}

// New creates new Buffer backed by the given filename and capped to the given
// capacity.
func New(filename string, capacity int) (Buffer, error) {
	dataFile1, err := openDataFile(filename, 1)
	if err != nil {
		return nil, err
	}
	dataFile2, err := openDataFile(filename, 2)
	if err != nil {
		return nil, err
	}
	idxFilename := fmt.Sprintf("%v_idx", filename)
	idxFile, err := openFile(idxFilename)
	if err != nil {
		return nil, err
	}
	fileInfo, err := idxFile.Stat()
	if err != nil {
		return nil, fmt.Errorf("Unable to stat file %v: %v", idxFile.Name(), err)
	}
	b := &buffer{
		capacity:    capacity,
		size:        0,
		nextIdx:     0,
		pointers:    make([]filepointer, capacity),
		startOfData: int64(headerSize + capacity*filePointerSize),
		idxFile:     idxFile,
		dataFiles:   []*os.File{dataFile1, dataFile2},
	}
	if fileInfo.Size() > 0 {
		log.Debug("Index already contains data, read metadata")
		err = b.readMetadata()
		if err != nil {
			return nil, err
		}
	}

	return b, nil
}

func openDataFile(filename string, idx int) (*os.File, error) {
	return openFile(fmt.Sprintf("%v_%d", filename, idx))
}

func openFile(filename string) (*os.File, error) {
	file, err := os.OpenFile(filename, os.O_RDWR|os.O_CREATE, 0600)
	if err != nil {
		return nil, fmt.Errorf("Unable to open file %v: %v", filename, err)
	}
	return file, nil
}

func (b *buffer) Write(p []byte) (int, error) {
	dataFile := b.dataFiles[b.nextPointer.file]
	dataFile.Seek(b.nextPointer.offset, 0)
	n, err := dataFile.Write(p)
	if err != nil {
		return n, err
	}

	b.updatePointerForCurrent(n)
	if err != nil {
		return 0, err
	}

	b.nextIdx++
	if b.nextIdx == b.capacity {
		// Wrap
		b.wrap()
	}
	b.size++
	if b.size >= b.capacity {
		b.size = b.capacity
	}

	err = b.writeMetadata()
	if err != nil {
		return 0, fmt.Errorf("Unable to write metadata: %v", err)
	}
	return n, err
}

func (b *buffer) updatePointerForCurrent(n int) {
	pointer := &b.pointers[b.nextIdx]
	pointer.file = b.nextPointer.file
	pointer.offset = b.nextPointer.offset
	pointer.length = int64(n)
	b.nextPointer.offset += pointer.length
}

func (b *buffer) AllFromOldest(onValue func(io.Reader) error) error {
	if b.size == 0 {
		return nil
	}

	startIdx := b.nextIdx
	if startIdx == b.size {
		// wrap
		startIdx = 0
	}

	for i := 0; i < b.size; i++ {
		idx := startIdx + i
		if idx >= b.capacity {
			// wrap
			idx -= b.capacity
		}
		pointer := &b.pointers[idx]
		dataFile := b.dataFiles[pointer.file]
		_, err := dataFile.Seek(pointer.offset, 0)
		if err != nil {
			// Fail immediately
			return fmt.Errorf("Unable to seek to next item: %v", err)
		}
		err = onValue(io.LimitReader(dataFile, pointer.length))
		if err != nil {
			return err
		}
	}

	return nil
}

func (b *buffer) wrap() {
	b.nextIdx = 0
	b.nextPointer.file = 1 - b.nextPointer.file
	b.nextPointer.offset = 0
}

func (b *buffer) readMetadata() error {
	p := make([]byte, b.startOfData)
	_, err := io.ReadFull(b.idxFile, p)
	if err != nil {
		log.Debugf("Unable to read initial metadata from %v, discarding existing data: %v", b.idxFile.Name(), err)
		return b.truncate()
	}
	b.size = int(endianness.Uint32(p[int32Size:]))
	if b.size > b.capacity {
		log.Debug("Capacity reduced, ignoring existing data")
		b.size = b.capacity
	}
	b.nextIdx = int(endianness.Uint32(p[int32Size*2:]))
	readPointer(p[int32Size*3:], &b.nextPointer)
	if b.nextIdx >= b.capacity {
		log.Debug("Next index exceeded capacity, wrap")
		b.wrap()
	}

	for i := 0; i < b.size; i++ {
		start := headerSize + i*filePointerSize
		readPointer(p[start:], &b.pointers[i])
	}
	return nil
}

func (b *buffer) writeMetadata() error {
	p := make([]byte, b.startOfData-int32Size)
	// Save size, nextIdx and nextPointer
	endianness.PutUint32(p, uint32(b.size))
	endianness.PutUint32(p[int32Size:], uint32(b.nextIdx))
	writePointer(p[int32Size*2:], &b.nextPointer)

	// Save all pointers
	for i := 0; i < b.size; i++ {
		start := headerSize - int32Size + i*filePointerSize
		writePointer(p[start:], &b.pointers[i])
	}

	// Write to disk
	_, err := b.idxFile.WriteAt(p, int32Size)
	if err != nil {
		return fmt.Errorf("Unable to write metadata: %v", err)
	}
	return nil
}

func readPointer(p []byte, pointer *filepointer) {
	pointer.file = int(p[0])
	pointer.offset = int64(endianness.Uint64(p[int8Size:]))
	pointer.length = int64(endianness.Uint64(p[int8Size+int64Size:]))
}

func writePointer(p []byte, pointer *filepointer) {
	p[0] = byte(pointer.file)
	endianness.PutUint64(p[int8Size:], uint64(pointer.offset))
	endianness.PutUint64(p[int8Size+int64Size:], uint64(pointer.length))
}

func (b *buffer) truncate() error {
	var finalError error
	allFiles := []*os.File{b.idxFile, b.dataFiles[0], b.dataFiles[1]}
	for _, file := range allFiles {
		err := file.Truncate(0)
		if err != nil {
			log.Error(err)
			finalError = fmt.Errorf("Unable to truncate file %v: %v", file.Name(), err)
		}
	}
	return finalError
}

func (b *buffer) Close() error {
	var finalError error
	allFiles := []*os.File{b.idxFile, b.dataFiles[0], b.dataFiles[1]}
	for _, file := range allFiles {
		err := file.Close()
		if err != nil {
			log.Error(err)
			finalError = fmt.Errorf("Unable to close file %v: %v", file.Name(), err)
		}
	}
	return finalError
}
