// Copyright 2014 The Go Authors. All rights reserved.
// Use of this source code is governed by a BSD-style
// license that can be found in the LICENSE file.

// +build darwin linux windows

package glutil // import "golang.org/x/mobile/exp/gl/glutil"

import (
	"fmt"

	"golang.org/x/mobile/exp/f32"
	"golang.org/x/mobile/gl"
)

// CreateProgram creates, compiles, and links a gl.Program.
func CreateProgram(glctx gl.Context, vertexSrc, fragmentSrc string) (gl.Program, error) {
	program := glctx.CreateProgram()
	if program.Value == 0 {
		return gl.Program{}, fmt.Errorf("glutil: no programs available")
	}

	vertexShader, err := loadShader(glctx, gl.VERTEX_SHADER, vertexSrc)
	if err != nil {
		return gl.Program{}, err
	}
	fragmentShader, err := loadShader(glctx, gl.FRAGMENT_SHADER, fragmentSrc)
	if err != nil {
		glctx.DeleteShader(vertexShader)
		return gl.Program{}, err
	}

	glctx.AttachShader(program, vertexShader)
	glctx.AttachShader(program, fragmentShader)
	glctx.LinkProgram(program)

	// Flag shaders for deletion when program is unlinked.
	glctx.DeleteShader(vertexShader)
	glctx.DeleteShader(fragmentShader)

	if glctx.GetProgrami(program, gl.LINK_STATUS) == 0 {
		defer glctx.DeleteProgram(program)
		return gl.Program{}, fmt.Errorf("glutil: %s", glctx.GetProgramInfoLog(program))
	}
	return program, nil
}

func loadShader(glctx gl.Context, shaderType gl.Enum, src string) (gl.Shader, error) {
	shader := glctx.CreateShader(shaderType)
	if shader.Value == 0 {
		return gl.Shader{}, fmt.Errorf("glutil: could not create shader (type %v)", shaderType)
	}
	glctx.ShaderSource(shader, src)
	glctx.CompileShader(shader)
	if glctx.GetShaderi(shader, gl.COMPILE_STATUS) == 0 {
		defer glctx.DeleteShader(shader)
		return gl.Shader{}, fmt.Errorf("shader compile: %s", glctx.GetShaderInfoLog(shader))
	}
	return shader, nil
}

// writeAffine writes the contents of an Affine to a 3x3 matrix GL uniform.
func writeAffine(glctx gl.Context, u gl.Uniform, a *f32.Affine) {
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
	glctx.UniformMatrix3fv(u, m[:])
}
