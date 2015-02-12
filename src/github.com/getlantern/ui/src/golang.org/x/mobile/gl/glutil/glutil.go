// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package glutil implements OpenGL utility functions.
package glutil // import "golang.org/x/mobile/gl/glutil"

import (
	"fmt"

	"golang.org/x/mobile/gl"
)

// CreateProgram creates, compiles, and links a gl.Program.
func CreateProgram(vertexSrc, fragmentSrc string) (gl.Program, error) {
	program := gl.CreateProgram()
	if program.Value == 0 {
		return gl.Program{}, fmt.Errorf("glutil: no programs available")
	}

	vertexShader, err := loadShader(gl.VERTEX_SHADER, vertexSrc)
	if err != nil {
		return gl.Program{}, err
	}
	fragmentShader, err := loadShader(gl.FRAGMENT_SHADER, fragmentSrc)
	if err != nil {
		gl.DeleteShader(vertexShader)
		return gl.Program{}, err
	}

	gl.AttachShader(program, vertexShader)
	gl.AttachShader(program, fragmentShader)
	gl.LinkProgram(program)

	// Flag shaders for deletion when program is unlinked.
	gl.DeleteShader(vertexShader)
	gl.DeleteShader(fragmentShader)

	if gl.GetProgrami(program, gl.LINK_STATUS) == 0 {
		defer gl.DeleteProgram(program)
		return gl.Program{}, fmt.Errorf("glutil: %s", gl.GetProgramInfoLog(program))
	}
	return program, nil
}

func loadShader(shaderType gl.Enum, src string) (gl.Shader, error) {
	shader := gl.CreateShader(shaderType)
	if shader.Value == 0 {
		return gl.Shader{}, fmt.Errorf("glutil: could not create shader (type %v)", shaderType)
	}
	gl.ShaderSource(shader, src)
	gl.CompileShader(shader)
	if gl.GetShaderi(shader, gl.COMPILE_STATUS) == 0 {
		defer gl.DeleteShader(shader)
		return gl.Shader{}, fmt.Errorf("shader compile: %s", gl.GetShaderInfoLog(shader))
	}
	return shader, nil
}
