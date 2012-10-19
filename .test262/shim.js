function $ERROR(message) {
    console.log(message)
}

function runTestCase(fn) {
    if (fn()) {
        console.log("pass")
    } else {
        console.log("=== fail")
    }
}

// ---
