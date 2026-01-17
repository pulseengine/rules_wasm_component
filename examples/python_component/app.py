"""Hello World Python WebAssembly Component

This demonstrates building a Python WebAssembly component using componentize-py.
The component exports a single `hello` function that returns a greeting.

Run with: wasmtime run bazel-bin/examples/python_component/hello_python.wasm

componentize-py generates bindings in the `wit_world` module.
We import and extend the generated `WitWorld` class to implement our exports.
The class must be named exactly `WitWorld` - this is a componentize-py requirement.
"""

import wit_world

class WitWorld(wit_world.WitWorld):
    """Implementation of the 'hello' WIT world exports.

    This class inherits from the generated bindings and implements
    the exported functions defined in hello.wit.
    """

    def hello(self) -> str:
        """Return a hello greeting.

        This method implements the `hello: func() -> string` export
        from the WIT definition.
        """
        return "Hello from Python WebAssembly!"
