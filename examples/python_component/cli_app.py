"""Python WebAssembly CLI Binary Example

This demonstrates building a Python CLI program using componentize-py
targeting the wasi:cli/command world.

Run with: wasmtime run bazel-bin/examples/python_component/hello_cli.wasm

The Run.run() pattern is Python's equivalent of main() for WASI CLI commands.
"""

from wit_world import exports


class Run(exports.Run):
    """Implementation of wasi:cli/run export.

    This class is Python's equivalent of main() for WebAssembly CLI programs.
    The run() method is called when the component is executed.
    """

    def run(self) -> None:
        """Entry point for the CLI program.

        This method implements the wasi:cli/run export, making the component
        executable with `wasmtime run`.
        """
        print("Hello from Python WebAssembly CLI!")
        print("")
        print("This is a WASI CLI command built with componentize-py.")
        print("It exports wasi:cli/run and can be executed directly.")
