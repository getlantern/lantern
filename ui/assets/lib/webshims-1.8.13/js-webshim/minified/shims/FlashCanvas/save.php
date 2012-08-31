<?php

/**
 * Save the input as a PNG file
 *
 * PHP versions 4 and 5
 *
 * Copyright (c) 2010-2011 Shinya Muramatsu
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * @author     Shinya Muramatsu <revulon@gmail.com>
 * @copyright  2010-2011 Shinya Muramatsu
 * @license    http://www.opensource.org/licenses/mit-license.php  MIT License
 * @link       http://flashcanvas.net/
 * @link       http://code.google.com/p/flashcanvas/
 */

if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    // Force download
    header('Content-Type: application/octet-stream');
    header('Content-Disposition: attachment; filename="canvas.png"');

    if (isset($_POST['dataurl'])) {
        // Decode the base64-encoded data
        $data = $_POST['dataurl'];
        $data = substr($data, strpos($data, ',') + 1);
        echo base64_decode($data);
    } else {
        // Output the raw data
        readfile('php://input');
    }
}
