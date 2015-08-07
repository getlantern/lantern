// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// Package glutil implements OpenGL utility functions.
package glutil // import "golang.org/x/mobile/exp/gl/glutil"

import (
	"fmt"

	"golang.org/x/mobile/exp/f32"
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

// writeAffine writes the contents of an Affine to a 3x3 matrix GL uniform.
func writeAffine(u gl.Uniform, a *f32.Affine) {
	var m [9]float32
	m[0*3+0] = a[0][0]
	m[0*3+1] = a[1][0]
	m[0*3+2] = 0
	m[1*3+0] = a[0][1]
	m[1*3+1] = a[1][1]
	m[1*3+2] = 0
	m[2*3+0] = a[0][2]
	m[2*3+1] = a[1][2]
	m[2*3+2] = 1
	gl.UniformMatrix3fv(u, m[:])
}
