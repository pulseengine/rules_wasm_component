"""Centralized checksum registry API for WebAssembly toolchain

This module provides a unified API for accessing tool checksums from JSON files.
"""

def _load_tool_checksums_from_json(repository_ctx, tool_name):
    """Load checksums for a tool from JSON file

    Args:
        repository_ctx: Repository context for file operations
        tool_name: Name of the tool (e.g., 'wasm-tools', 'wit-bindgen')

    Returns:
        Dict: Tool data from JSON file, or None if file not found
    """
    json_file = repository_ctx.path(Label("@rules_wasm_component//checksums/tools:{}.json".format(tool_name)))
    if not json_file.exists:
        return None

    content = repository_ctx.read(json_file)
    return json.decode(content)

def _load_tool_checksums(tool_name):
    """Load checksums for a tool from embedded fallback data

    Args:
        tool_name: Name of the tool (e.g., 'wasm-tools', 'wit-bindgen')

    Returns:
        Dict: Tool data from embedded registry, or empty dict if not found

    Note:
        This is fallback data for non-repository contexts.
        Use _load_tool_checksums_from_json() in repository rules for up-to-date data.
    """

    tool_data = _get_fallback_checksums(tool_name)
    return tool_data

def _get_fallback_checksums(tool_name):
    """Fallback checksums sourced from JSON files

    This data is synchronized with checksums/tools/*.json files.
    Eventually this will be replaced with direct JSON loading.
    """

    fallback_data = {
        "file-ops-component": {
            "tool_name": "file-ops-component",
            "github_repo": "pulseengine/bazel-file-ops-component",
            "latest_version": "0.2.0",
            "versions": {
                "0.1.0-rc.3": {
                    "release_date": "2024-10-24",
                    "platforms": {
                        "wasm_component_aot": {
                            "sha256": "4fc117fae701ffd74b03dd72bbbeaf4ccdd1677ad15effa5c306a809de256938",
                            "url_suffix": "file_ops_component_aot.wasm",
                            "notes": "AOT-embedded variant with native code for Linux/macOS/Windows x64+ARM64. 100x faster startup.",
                            "size_kb": 22851,
                        },
                        "wasm_component": {
                            "sha256": "8a9b1aa8a2c9d3dc36f1724ccbf24a48c473808d9017b059c84afddc55743f1e",
                            "url_suffix": "file_ops_component.wasm",
                            "notes": "Regular WASM variant (identical to rc.2). For AOT variant, see wasm_component_aot.",
                            "size_kb": 853,
                        }
                    },
                },
                "0.2.0": {
                    "release_date": "2025-11-01",
                    "platforms": {
                        "wasm_component": {
                            "sha256": "b31271501e44e92f95c1399ed655af00e54ab23bddc83fb7300890f75ea7e373",
                            "url_suffix": "file_ops_component.wasm",
                            "notes": "Includes concatenate-files operation for file merging",
                            "size_kb": 874,
                        }
                    },
                },
                "0.1.0-rc.2": {
                    "release_date": "2024-10-24",
                    "platforms": {
                        "wasm_component": {
                            "sha256": "8a9b1aa8a2c9d3dc36f1724ccbf24a48c473808d9017b059c84afddc55743f1e",
                            "url_suffix": "file_ops_component.wasm",
                            "size_kb": 853,
                        }
                    },
                }
            },
        },
        "jco": {
            "tool_name": "jco",
            "github_repo": "bytecodealliance/jco",
            "latest_version": "1.4.0",
            "versions": {
                "1.4.0": {
                    "release_date": "2024-11-25",
                    "platforms": {
                        "universal": {
                            "sha256": "",
                            "url_suffix": "",
                            "dependencies": ["@bytecodealliance/componentize-js"],
                            "npm_package": "@bytecodealliance/jco",
                            "npm_version": "1.4.0",
                        }
                    },
                }
            },
        },
        "nodejs": {
            "tool_name": "nodejs",
            "github_repo": "nodejs/node",
            "latest_version": "24.12.0",
            "versions": {
                "24.12.0": {
                    "release_date": "2025-12-10",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "9b2a2eeb98a8eb37361224e2a1d060300ad2dd143af58dfdb16de785df0f1228",
                            "url_suffix": "linux-arm64.tar.xz",
                        },
                        "darwin_arm64": {
                            "sha256": "319f221adc5e44ff0ed57e8a441b2284f02b8dc6fc87b8eb92a6a93643fd8080",
                            "url_suffix": "darwin-arm64.tar.gz",
                        }
                    },
                },
                "20.18.0": {
                    "release_date": "2024-10-03",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "c02aa7560612a4e2cc359fd89fae7aedde370c06db621f2040a4a9f830a125dc",
                            "url_suffix": "darwin-x64.tar.gz",
                            "binary_path": "node-v{}-darwin-x64/bin/node",
                            "npm_path": "node-v{}-darwin-x64/bin/npm",
                        },
                        "windows_amd64": {
                            "sha256": "f5cea43414cc33024bbe5867f208d1c9c915d6a38e92abeee07ed9e563662297",
                            "url_suffix": "win-x64.zip",
                            "binary_path": "node-v{}-win-x64/node.exe",
                            "npm_path": "node-v{}-win-x64/npm.cmd",
                        },
                        "linux_amd64": {
                            "sha256": "24a5d58a1d4c2903478f4b7c3cfd2eeb5cea2cae3baee11a4dc6a1fed25fec6c",
                            "url_suffix": "linux-x64.tar.gz",
                            "binary_path": "node-v{}-linux-x64/bin/node",
                            "npm_path": "node-v{}-linux-x64/bin/npm",
                        },
                        "linux_arm64": {
                            "sha256": "38bccb35c06ee4edbcd00c77976e3fad1d69d2e57c3c0c363d1700a2a2493278",
                            "url_suffix": "linux-arm64.tar.gz",
                            "binary_path": "node-v{}-linux-arm64/bin/node",
                            "npm_path": "node-v{}-linux-arm64/bin/npm",
                        },
                        "darwin_arm64": {
                            "sha256": "92e180624259d082562592bb12548037c6a417069be29e452ec5d158d657b4be",
                            "url_suffix": "darwin-arm64.tar.gz",
                            "binary_path": "node-v{}-darwin-arm64/bin/node",
                            "npm_path": "node-v{}-darwin-arm64/bin/npm",
                        }
                    },
                },
                "18.20.8": {
                    "release_date": "2024-09-03",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "ed2554677188f4afc0d050ecd8bd56effb2572d6518f8da6d40321ede6698509",
                            "url_suffix": "darwin-x64.tar.gz",
                            "binary_path": "node-v{}-darwin-x64/bin/node",
                            "npm_path": "node-v{}-darwin-x64/bin/npm",
                        },
                        "darwin_arm64": {
                            "sha256": "bae4965d29d29bd32f96364eefbe3bca576a03e917ddbb70b9330d75f2cacd76",
                            "url_suffix": "darwin-arm64.tar.gz",
                            "binary_path": "node-v{}-darwin-arm64/bin/node",
                            "npm_path": "node-v{}-darwin-arm64/bin/npm",
                        },
                        "linux_amd64": {
                            "sha256": "27a9f3f14d5e99ad05a07ed3524ba3ee92f8ff8b6db5ff80b00f9feb5ec8097a",
                            "url_suffix": "linux-x64.tar.gz",
                            "binary_path": "node-v{}-linux-x64/bin/node",
                            "npm_path": "node-v{}-linux-x64/bin/npm",
                        },
                        "linux_arm64": {
                            "sha256": "2e3dfc51154e6fea9fc86a90c4ea8f3ecb8b60acaf7367c4b76691da192571c1",
                            "url_suffix": "linux-arm64.tar.gz",
                            "binary_path": "node-v{}-linux-arm64/bin/node",
                            "npm_path": "node-v{}-linux-arm64/bin/npm",
                        },
                        "windows_amd64": {
                            "sha256": "1a1e40260a6facba83636e4cd0ba01eb5bd1386896824b36645afba44857384a",
                            "url_suffix": "win-x64.zip",
                            "binary_path": "node-v{}-win-x64/node.exe",
                            "npm_path": "node-v{}-win-x64/npm.cmd",
                        }
                    },
                }
            },
        },
        "tinygo": {
            "tool_name": "tinygo",
            "github_repo": "tinygo-org/tinygo",
            "latest_version": "0.40.1",
            "versions": {
                "0.40.1": {
                    "release_date": "2025-12-19",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "064fc0c07f4d71f7369b168c337caa88ef32a6b00b16449cea44790ccadfc2b4",
                            "url_suffix": "linux-amd64.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "a20841a616de3b3403e52e3789cb60c147ab52b3fe6c33b31fdffba0164ae031",
                            "url_suffix": "darwin-arm64.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "4720693b333826569d5c1ed746a735c4d1983719c95af5bdd4d9dfeaa755e933",
                            "url_suffix": "linux-arm64.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "36c9423a63f9548d142908b06c67e198d878a0fed076b8ec5dbf8a3350a73eb4",
                            "url_suffix": "darwin-amd64.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "7f839546df47e52a8ec9031437ae374a1facceb9adb15b94d514624fed9391b4",
                            "url_suffix": "windows-amd64.zip",
                        }
                    },
                }
            },
        },
        "go": {
            "tool_name": "go",
            "download_base": "https://go.dev/dl",
            "latest_version": "1.25.3",
            "versions": {
                "1.25.3": {
                    "release_date": "2025-10-13",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "1641050b422b80dfd6299f8aa7eb8798d1cd23eac7e79f445728926e881b7bcd",
                            "url_suffix": "darwin-amd64.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "7c083e3d2c00debfeb2f77d9a4c00a1aac97113b89b9ccc42a90487af3437382",
                            "url_suffix": "darwin-arm64.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "0335f314b6e7bfe08c3d0cfaa7c19db961b7b99fb20be62b0a826c992ad14e0f",
                            "url_suffix": "linux-amd64.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "1d42ebc84999b5e2069f5e31b67d6fc5d67308adad3e178d5a2ee2c9ff2001f5",
                            "url_suffix": "linux-arm64.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "bc249a599c6fe9d0d4093c363856f6c6320dbbe05e5d5d8818b711fb4a14fc23",
                            "url_suffix": "windows-amd64.zip",
                        }
                    },
                }
            },
        },
        "binaryen": {
            "tool_name": "binaryen",
            "github_repo": "WebAssembly/binaryen",
            "latest_version": "123",
            "versions": {
                "123": {
                    "release_date": "2025-03-27",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "cc18b14d2b673d9c66bf54f31ff2b0ceb23ba5132455b893965ae2792f9e00dd",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "74428be348c1a09863e7b642a1fa948cabf8ec9561052233d8288e941951725b",
                            "url_suffix": "arm64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "e959f2170af4c20c552e9de3a0253704d6a9d2766e8fdb88e4d6ac4bae9388fe",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "4b6bd61ba6cd3b18c993b4657d93426c782f9b91b74be0d38018cd8be1319376",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "7b3568424a0f871a52865d5c78177db646b1832a8c487321e27703103f936880",
                            "url_suffix": "x86_64-windows.tar.gz",
                        }
                    },
                }
            },
        },
        "wac": {
            "tool_name": "wac",
            "github_repo": "bytecodealliance/wac",
            "latest_version": "0.8.1",
            "versions": {
                "0.8.1": {
                    "release_date": "2025-11-11",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "ce30f33c5bc40095cfb4e74ae5fb4ba515d4f4bef2d597831bc7afaaf0d55b6c",
                            "platform_name": "x86_64-unknown-linux-musl",
                        },
                        "windows_amd64": {
                            "sha256": "b3509dfc3bb9d1e598e7b2790ef6efe5b6c8b696f2ad0e997e9ae6dd20bb6f13",
                            "platform_name": "x86_64-pc-windows-gnu",
                        },
                        "linux_arm64": {
                            "sha256": "3b78ae7c732c1376d1c21b570d07152a07342e9c4f75bff1511cde5f6af01f12",
                            "platform_name": "aarch64-unknown-linux-musl",
                        },
                        "darwin_arm64": {
                            "sha256": "f08496f49312abd68d9709c735a987d6a17d2295a1240020d217a9de8dcaaacd",
                            "platform_name": "aarch64-apple-darwin",
                        },
                        "darwin_amd64": {
                            "sha256": "d5fa365a4920d19a61837a42c9273b0b8ec696fd3047af864a860f46005773a5",
                            "platform_name": "x86_64-apple-darwin",
                        }
                    },
                },
                "0.8.0": {
                    "release_date": "2025-08-20",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "af966d4efbd411900073270bd4261ac42d9550af8ba26ed49288bb942476c5a9",
                            "platform_name": "aarch64-unknown-linux-musl",
                        },
                        "windows_amd64": {
                            "sha256": "7ee34ea41cd567b2578929acce3c609e28818d03f0414914a3939f066737d872",
                            "platform_name": "x86_64-pc-windows-gnu",
                        },
                        "darwin_amd64": {
                            "sha256": "cc58f94c611b3b7f27b16dd0a9a9fc63c91c662582ac7eaa9a14f2dac87b07f8",
                            "platform_name": "x86_64-apple-darwin",
                        },
                        "darwin_arm64": {
                            "sha256": "6ca7f69f3e2bbab41f375a35e486d53e5b4968ea94271ea9d9bd59b0d2b65c13",
                            "platform_name": "aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "9fee2d8603dc50403ebed580b47b8661b582ffde8a9174bf193b89ca00decf0f",
                            "platform_name": "x86_64-unknown-linux-musl",
                        }
                    },
                }
            },
        },
        "wasi-sdk": {
            "tool_name": "wasi-sdk",
            "github_repo": "WebAssembly/wasi-sdk",
            "latest_version": "29",
            "versions": {
                "29": {
                    "release_date": "2025-11-15",
                    "platforms": {
                        "windows_amd64": {
                            "sha256": "ea5eb0580ffa1530644dd1fed1f7117ad72ec3d7956901561470a3b8c54cce43",
                            "url_suffix": "x86_64-windows.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "d0de2fd3ea5c57060efa87e4356c164bec3689972f2386f0c9a89c58e10cec8d",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "e11552913e3f99e834d7fe7da1bd081abaf764759ed76b6097a34c63fc83665e",
                            "url_suffix": "arm64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "87d1d1a2879d139cdc624b968efad3d4a97b8078cdff95e63ac88ecafd1a0171",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "052ad773397dc9e5aa99fb4cfef694175e6b1e81bb2ad1d3c8e7b3fc81441b7c",
                            "url_suffix": "arm64-linux.tar.gz",
                        }
                    },
                },
                "26": {
                    "release_date": "2025-07-28",
                    "platforms": {
                        "darwin_arm64": {
                            "sha256": "f6c76a183cf7fce9fc8af95b10f851a679f8ea6dae0354c5f84b52157a3398e1",
                            "url_suffix": "macos.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "9853b66701d017cb17e53beb2e540e522bdded772fd1661ce29a88eb8b333902",
                            "url_suffix": "macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "7ba6e76f2b1bb7b85429ebe96a4d867923f14cbd77a55f31fca6e02b26fe0754",
                            "url_suffix": "linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "PLACEHOLDER_NEEDS_REAL_CHECKSUM_64_CHARS_XXXXXXXXXXXXXXXX",
                            "url_suffix": "windows.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "37cddd06e354b0354db40e42a011752b0d5b77075af4bc5a2e0999aab908484e",
                            "url_suffix": "linux.tar.gz",
                        }
                    },
                },
                "27": {
                    "release_date": "2025-07-28",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "b7d4d944c88503e4f21d84af07ac293e3440b1b6210bfd7fe78e0afd92c23bc2",
                            "url_suffix": "linux.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "163dfd47f989b1a682744c1ae1f0e09a83ff5c4bbac9dcd8546909ab54cda5a1",
                            "url_suffix": "macos.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "4a576c13125c91996d8cc3b70b7ea0612c2044598d2795c9be100d15f874adf6",
                            "url_suffix": "x86_64-windows.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "4cf4c553c4640e63e780442146f87d83fdff5737f988c06a6e3b2f0228e37665",
                            "url_suffix": "linux.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "055c3dc2766772c38e71a05d353e35c322c7b2c6458a36a26a836f9808a550f8",
                            "url_suffix": "macos.tar.gz",
                        }
                    },
                }
            },
        },
        "wasm-tools": {
            "tool_name": "wasm-tools",
            "github_repo": "bytecodealliance/wasm-tools",
            "latest_version": "1.243.0",
            "versions": {
                "1.241.2": {
                    "release_date": "2025-11-14",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "abc5a70c5cade497805998fd0b5cd545df9b484c62f16d33dd6a4cad135302aa",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "9eb1af8331ec073d37bb025598426dcb747bd51db085861066e123b9e823fa52",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "darwin_arm64": {
                            "sha256": "96dbe14cde4a1e48781af959b623e045a2cab106756476039309f8e6266906a3",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "ded5228bd4f7b06c7ec7bee31b570daa72022c28fdd890d23cd2837e3914d117",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "5ead4459eef50f4b83b47151332f22e4bcfea9c1917e816273b807b2d6567199",
                            "url_suffix": "x86_64-linux.tar.gz",
                        }
                    },
                },
                "1.239.0": {
                    "release_date": "2024-09-09",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "d62482e2bfe65a05f4c313f2d57b09736054e37f4dfe94b4bdf7b4713b03fa02",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "54bb0fdad016a115bde8dd7d2cd63e88d0b136a44ab23ae9c3ff4d4d48d5fa4d",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "b65777dcb9873b404e50774b54b61b703eb980cadb20ada175a8bf74bfe23706",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "039b1eaa170563f762355a23c5ee709790199433e35e5364008521523e9e3398",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "linux_amd64": {
                            "sha256": "be1764c1718a2ed90cdd3e1ed2fe6e4c6b3e2b69fb6ba9a85bcafdca5146a3b9",
                            "url_suffix": "x86_64-linux.tar.gz",
                        }
                    },
                },
                "1.240.0": {
                    "release_date": "2025-10-08",
                    "platforms": {
                        "darwin_arm64": {
                            "sha256": "ecdce0140b4b6394b4fa6deab53f19037ce08e8d618e6a7d108b455504ab03e7",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "e3d497196bf99a31a62c885d2f5c3aa1e4d4a6bc02c1bff735ffa6a4c7aa9c2f",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "81f012832e80fe09d384d86bb961d4779f6372a35fa965cc64efe318001ab27e",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "darwin_amd64": {
                            "sha256": "8959eb9f494af13868af9e13e74e4fa0fa6c9306b492a9ce80f0e576eb10c0c6",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "b6ad301b8ac65e283703d1a5cf79280058a5f5699f8ff1fcaf66dbcf80a9efae",
                            "url_suffix": "x86_64-linux.tar.gz",
                        }
                    },
                },
                "1.243.0": {
                    "release_date": "2025-12-03",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "ad06ba3c527992a1e6e9a7e807cc2bb914072f0a0ae6ce71680de91b1054d2e9",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "6690a33a06ef705a63dbc066210bc0f09b1c08a82952d3cde9fbebd0d484b46f",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "3d03bc02fed63998e0ee8d88eb86d90bdb8e32e7cadc77d2f9e792b9dff8433a",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "f261622f8015d38ebe9c3345cc2f7bb5de055d3a66ab44efdf78f11068ed9d9f",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "bb04533ff517f6c90df129f2a358b18ca45b7400a3676ba935bbd787908ff6b8",
                            "url_suffix": "x86_64-windows.zip",
                        }
                    },
                }
            },
        },
        "wasmsign2-cli": {
            "tool_name": "wasmsign2-cli",
            "github_repo": "pulseengine/wasmsign2",
            "latest_version": "0.2.7-rc.2",
            "versions": {
                "0.2.7-rc.2": {
                    "release_date": "2025-10-30",
                    "platforms": {
                        "wasm_component": {
                            "sha256": "0a2ba6a55621d83980daa7f38e3770ba6b9342736971a0cebf613df08377cd34",
                            "url_suffix": "wasmsign2-cli.wasm",
                            "downloaded_file_path": "wasmsign2.wasm",
                        }
                    },
                }
            },
        },
        "wasmtime": {
            "tool_name": "wasmtime",
            "github_repo": "bytecodealliance/wasmtime",
            "latest_version": "39.0.1",
            "versions": {
                "37.0.2": {
                    "release_date": "2025-09-04",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "a84fef229c2d11e3635ea369688971dc48abc0732f7b50b696699183043f962e",
                            "url_suffix": "x86_64-linux.tar.xz",
                        },
                        "linux_arm64": {
                            "sha256": "eb306a71e3ec232815326ca6354597b43c565b9ceda7d771529bfc4bd468dde9",
                            "url_suffix": "aarch64-linux.tar.xz",
                        },
                        "darwin_arm64": {
                            "sha256": "369012921015d627c51fa9e1d1c5b7dff9b3d799a7ec5ce7d0b27bc40434e91c",
                            "url_suffix": "aarch64-macos.tar.xz",
                        },
                        "darwin_amd64": {
                            "sha256": "6bbc40d77e4779f711af60314b32c24371ffc9dbcb5d8b9961bd93ecd9e0f111",
                            "url_suffix": "x86_64-macos.tar.xz",
                        },
                        "windows_amd64": {
                            "sha256": "9aaa2406c990e773cef8d90f409982fac28d3d330ad40a5fab1233b8c5d88795",
                            "url_suffix": "x86_64-windows.zip",
                        }
                    },
                },
                "35.0.0": {
                    "release_date": "2025-07-22",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "e3d2aae710a5cef548ab13f7e4ed23adc4fa1e9b4797049f4459320f32224011",
                            "url_suffix": "x86_64-linux.tar.xz",
                        },
                        "darwin_arm64": {
                            "sha256": "8ad8832564e15053cd982c732fac39417b2307bf56145d02ffd153673277c665",
                            "url_suffix": "aarch64-macos.tar.xz",
                        },
                        "linux_arm64": {
                            "sha256": "304009a9e4cad3616694b4251a01d72b77ae33d884680f3586710a69bd31b8f8",
                            "url_suffix": "aarch64-linux.tar.xz",
                        },
                        "windows_amd64": {
                            "sha256": "cb4d9b788e81268edfb43d26c37dc4115060635ff4eceed16f4f9e6f331179b1",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "darwin_amd64": {
                            "sha256": "1ef7d07b8a8ef7e261281ad6a1b14ebf462f84c534593ca20e70ec8097524247",
                            "url_suffix": "x86_64-macos.tar.xz",
                        }
                    },
                },
                "39.0.1": {
                    "release_date": "2025-11-24",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "bff5ebd3e6781620f40e5586f1aa221f7da98128dacf0142bfb4b25d12242274",
                            "url_suffix": "aarch64-linux.tar.xz",
                        },
                        "windows_amd64": {
                            "sha256": "bccf64b4227d178c0d13f2856be68876eae3f2f657f3a85d46f076a5e1976198",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "linux_amd64": {
                            "sha256": "b90a36125387b75db59a67a1c402f2ed9d120fa43670d218a559571e2423d925",
                            "url_suffix": "x86_64-linux.tar.xz",
                        },
                        "darwin_arm64": {
                            "sha256": "3878fc98ab1fec191476ddec5d195e6d018d7fbe5376e54d2c23aedf38aa1bd2",
                            "url_suffix": "aarch64-macos.tar.xz",
                        },
                        "darwin_amd64": {
                            "sha256": "d9ecdc6b423a59f09a63abe352f470d48fcd03a4d6bc0db5fcf57830f2832be6",
                            "url_suffix": "x86_64-macos.tar.xz",
                        }
                    },
                }
            },
        },
        "wit-bindgen": {
            "tool_name": "wit-bindgen",
            "github_repo": "bytecodealliance/wit-bindgen",
            "latest_version": "0.50.0",
            "versions": {
                "0.49.0": {
                    "release_date": "2025-12-03",
                    "platforms": {
                        "darwin_arm64": {
                            "sha256": "70f86d5381de89c50171bc82dd0c8bb0c15839acdb8a65994f67de324ba35cfa",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "b4fd152a408da7a048102b599aac617cf88a2f23dd20c47143d1166569823366",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "d8135e07a68870b0cc0ab27a1a6209b2ddbbe56e489cfbaf80bdfd64b4ba9b7c",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "darwin_amd64": {
                            "sha256": "8c8186feb76352b553e3571cbce82025930a35146687afd2fd779fef0496a75d",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "81a48c27604930543d6cc6bd99b71eac0654c2341a5d350baa5a85ceb58272d2",
                            "url_suffix": "aarch64-linux.tar.gz",
                        }
                    },
                },
                "0.43.0": {
                    "release_date": "2025-06-24",
                    "platforms": {
                        "darwin_amd64": {
                            "sha256": "4f3fe255640981a2ec0a66980fd62a31002829fab70539b40a1a69db43f999cd",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "dcd446b35564105c852eadb4244ae35625a83349ed1434a1c8e5497a2a267b44",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "cb6b0eab0f8abbf97097cde9f0ab7e44ae07bf769c718029882b16344a7cda64",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "5e492806d886e26e4966c02a097cb1f227c3984ce456a29429c21b7b2ee46a5b",
                            "url_suffix": "aarch64-macos.tar.gz",
                        }
                    },
                },
                "0.48.0": {
                    "release_date": "2025-11-14",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "a714502afceff580c4f60e9a4d6506d38f3f38ac60d541221826323668fd03ba",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "4d86c24822edd47ea6a362214c4804552a223b3ebd7bba8c6c56ff12cac4efd6",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "dd73eca91f80d2a87fbc8f9b2bf8737ea2348b90d322dc119b6203ac1e74cd52",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "c59e53e49aa5bff89e6dbbba4091aa655a5805f701479b05a65a28cc039c51d0",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "3e1f198de975678f83f33c348a984985829866ec6df7af6a12bfd98ec2cc037d",
                            "url_suffix": "x86_64-windows.zip",
                        }
                    },
                },
                "0.50.0": {
                    "release_date": "2025-12-23",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "a8d6710d11f71d80c2977fa925dc8d9b2fa31ba8044f71aa5c633ce6e1dcd72c",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "05aee2cd072c4964b2964a29877ac88d02fb640594a0207f419941acb0f6e301",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "67bef921145fc43e9c47b88af5ce6acc4c96cb68175280e1e71d672f5acc5dba",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "e7bf93e209b23be04ce22de9d5d4e15f8b1c3c270f84dfc0469a8167d24ab865",
                            "url_suffix": "aarch64-linux.tar.gz",
                        }
                    },
                },
                "0.48.1": {
                    "release_date": "2025-11-22",
                    "platforms": {
                        "windows_amd64": {
                            "sha256": "22ba86276ab059fa5cb2fd33faf5517c4eea5e48c9df5218d01f1db2400ec39f",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "darwin_arm64": {
                            "sha256": "38be6c864dc77a4aaaa5881fed723ead5352101f10a615478d4c34d536ddc6e5",
                            "url_suffix": "aarch64-macos.tar.gz",
                        },
                        "linux_amd64": {
                            "sha256": "319b8ed9445cf2f017c7e2f508cd9b3d8fa6bc1ff4b48b4d9983981c2a6b87b0",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "a81f9a9a1a76267f7e6d1985869feb1de2fd689c1426ba7acff76ab2e5312ac4",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "linux_arm64": {
                            "sha256": "cf22136f544cb466bb650b04170ea1df2d8a7d2492d926ee330320270f632104",
                            "url_suffix": "aarch64-linux.tar.gz",
                        }
                    },
                },
                "0.46.0": {
                    "release_date": "2025-11-01",
                    "platforms": {
                        "linux_amd64": {
                            "sha256": "8f426d9b0ed0150c71feea697effe4b90b1426a49e22e48bc1d4f4c6396bf771",
                            "url_suffix": "x86_64-linux.tar.gz",
                        },
                        "windows_amd64": {
                            "sha256": "95c6380ec7c1e385be8427a2da1206d90163fd66b6cbb573a516390988ccbad2",
                            "url_suffix": "x86_64-windows.zip",
                        },
                        "linux_arm64": {
                            "sha256": "37879138d1703f4063d167e882d3ecef24abd2df666d92a95bc5f8338644bfb4",
                            "url_suffix": "aarch64-linux.tar.gz",
                        },
                        "darwin_amd64": {
                            "sha256": "98767eb96f2a181998fa35a1df932adf743403c5f621ed6eedaa7d7c0533d543",
                            "url_suffix": "x86_64-macos.tar.gz",
                        },
                        "darwin_arm64": {
                            "sha256": "dc96da8f3d12bf5e2e3e3b00ce1474d2a8e77e36088752633380f0c85e18632c",
                            "url_suffix": "aarch64-macos.tar.gz",
                        }
                    },
                }
            },
        },
        "wkg": {
            "tool_name": "wkg",
            "github_repo": "bytecodealliance/wasm-pkg-tools",
            "latest_version": "0.13.0",
            "versions": {
                "0.11.0": {
                    "release_date": "2025-06-19",
                    "platforms": {
                        "linux_arm64": {
                            "sha256": "159ffe5d321217bf0f449f2d4bde9fe82fee2f9387b55615f3e4338eb0015e96",
                            "url_suffix": "wkg-aarch64-unknown-linux-gnu",
                        },
                        "darwin_amd64": {
                            "sha256": "f1b6f71ce8b45e4fae0139f4676bc3efb48a89c320b5b2df1a1fd349963c5f82",
                            "url_suffix": "wkg-x86_64-apple-darwin",
                        },
                        "darwin_arm64": {
                            "sha256": "e90a1092b1d1392052f93684afbd28a18fdf5f98d7175f565e49389e913d7cea",
                            "url_suffix": "wkg-aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "e3bec9add5a739e99ee18503ace07d474ce185d3b552763785889b565cdcf9f2",
                            "url_suffix": "wkg-x86_64-unknown-linux-gnu",
                        },
                        "windows_amd64": {
                            "sha256": "ac7b06b91ea80973432d97c4facd78e84187e4d65b42613374a78c4c584f773c",
                            "url_suffix": "wkg-x86_64-pc-windows-gnu",
                        }
                    },
                },
                "0.13.0": {
                    "release_date": "2025-11-10",
                    "platforms": {
                        "darwin_arm64": {
                            "sha256": "e8abc8195201fab2769a79ca3f831c3a7830714cd9508c3d1defff348942cbc6",
                            "url_suffix": "wkg-aarch64-apple-darwin",
                        },
                        "linux_amd64": {
                            "sha256": "59bb3bce8a0f7d150ab57cef7743fddd7932772c4df71d09072ed83acb609323",
                            "url_suffix": "wkg-x86_64-unknown-linux-gnu",
                        },
                        "linux_arm64": {
                            "sha256": "522d400dc919f026137c97a35bccc8a7b583aa29722a8cb4f470ff39de8161a0",
                            "url_suffix": "wkg-aarch64-unknown-linux-gnu",
                        },
                        "windows_amd64": {
                            "sha256": "fdb964cc986578778543890b19c9e96d6b8f1cbb2c1c45a6dafcf542141a59a4",
                            "url_suffix": "wkg-x86_64-pc-windows-gnu",
                        },
                        "darwin_amd64": {
                            "sha256": "6e9e260d45c8873d942ea5a1640692fdf01268c4b7906b48705dadaf1726a458",
                            "url_suffix": "wkg-x86_64-apple-darwin",
                        }
                    },
                },
                "0.12.0": {
                    "release_date": "2025-10-01",
                    "platforms": {
                        "darwin_arm64": {
                            "sha256": "0048768e7046a5df7d8512c4c87c56cbf66fc12fa8805e8fe967ef2118230f6f",
                            "url_suffix": "wkg-aarch64-apple-darwin",
                        },
                        "windows_amd64": {
                            "sha256": "930adea31da8d2a572860304c00903f7683966e722591819e99e26787e58416b",
                            "url_suffix": "wkg-x86_64-pc-windows-gnu",
                        },
                        "linux_amd64": {
                            "sha256": "444e568ce8c60364b9887301ab6862ef382ac661a4b46c2f0d2f0f254bd4e9d4",
                            "url_suffix": "wkg-x86_64-unknown-linux-gnu",
                        },
                        "linux_arm64": {
                            "sha256": "ebd6ffba1467c16dba83058a38e894496247fc58112efd87d2673b40fc406652",
                            "url_suffix": "wkg-aarch64-unknown-linux-gnu",
                        },
                        "darwin_amd64": {
                            "sha256": "15ea13c8fc1d2fe93fcae01f3bdb6da6049e3edfce6a6c6e7ce9d3c620a6defd",
                            "url_suffix": "wkg-x86_64-apple-darwin",
                        }
                    },
                }
            },
        }
    }

    return fallback_data.get(tool_name, {})

def get_tool_checksum(tool_name, version, platform):
    """Get verified checksum from centralized registry

    Args:
        tool_name: Name of the tool (e.g., 'wasm-tools', 'wit-bindgen')
        version: Version string (e.g., '1.235.0')
        platform: Platform string (e.g., 'darwin_amd64', 'linux_amd64')

    Returns:
        String: SHA256 checksum, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})
    platform_data = platforms.get(platform, {})

    return platform_data.get("sha256")

def get_tool_info(tool_name, version, platform):
    """Get complete tool information from centralized registry

    Args:
        tool_name: Name of the tool
        version: Version string
        platform: Platform string

    Returns:
        Dict: Complete platform information, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})

    return platforms.get(platform)

def get_latest_version(tool_name):
    """Get latest available version for a tool

    Args:
        tool_name: Name of the tool

    Returns:
        String: Latest version, or None if tool not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    return tool_data.get("latest_version")

def list_supported_platforms(tool_name, version):
    """List all supported platforms for a tool version

    Args:
        tool_name: Name of the tool
        version: Version string

    Returns:
        List: List of supported platform strings
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return []

    versions = tool_data.get("versions", {})
    version_data = versions.get(version, {})
    platforms = version_data.get("platforms", {})

    return list(platforms.keys())

def get_github_repo(tool_name):
    """Get GitHub repository for a tool

    Args:
        tool_name: Name of the tool

    Returns:
        String: GitHub repository in 'owner/repo' format, or None if not found
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return None

    return tool_data.get("github_repo")

def validate_tool_exists(tool_name, version, platform):
    """Validate that a tool version and platform combination exists

    Args:
        tool_name: Name of the tool
        version: Version string
        platform: Platform string

    Returns:
        Bool: True if the combination exists and has a checksum
    """

    checksum = get_tool_checksum(tool_name, version, platform)
    return checksum != None and len(checksum) == 64  # Valid SHA256 length

def get_tool_metadata(tool_name):
    """Get tool metadata including GitHub repo and latest version

    Args:
        tool_name: Name of the tool

    Returns:
        Dict: Tool metadata including github_repo, latest_version, etc.
    """

    tool_data = _load_tool_checksums(tool_name)
    if not tool_data:
        return {}

    return {
        "tool_name": tool_data.get("tool_name"),
        "github_repo": tool_data.get("github_repo"),
        "latest_version": tool_data.get("latest_version"),
        "build_type": tool_data.get("build_type", "binary"),
    }

def list_available_tools():
    """List all available tools in the registry

    Returns:
        List: List of available tool names
    """

    # Return tools that have fallback data available
    # Note: wizer removed - now part of wasmtime v39.0.0+, use `wasmtime wizer` subcommand
    return [
        "wasm-tools",
        "wit-bindgen",
        "wac",
        "wkg",
        "wasmtime",
        "wasi-sdk",
        "wasmsign2",
        "nodejs",
        "jco",
        "file-ops-component",
        "wasmsign2-cli",
        "go",
        "binaryen",
        "tinygo",
    ]

def validate_tool_compatibility(tools_config):
    """Validate that tool versions are compatible with each other

    Args:
        tools_config: Dict mapping tool names to versions

    Returns:
        List: List of warning messages for compatibility issues
    """

    warnings = []

    # Define compatibility matrix (sourced from tool_versions.bzl)
    compatibility_matrix = {
        "1.243.0": {
            "wac": ["0.8.0", "0.8.1"],
            "wit-bindgen": ["0.46.0", "0.48.1", "0.49.0"],
            "wkg": ["0.11.0", "0.12.0", "0.13.0"],
            "wasmsign2": ["0.2.6"],
        },
        "1.235.0": {
            "wac": ["0.7.0", "0.8.0", "0.8.1"],
            "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
            "wkg": ["0.11.0", "0.12.0", "0.13.0"],
            "wasmsign2": ["0.2.6"],
        },
        "1.239.0": {
            "wac": ["0.7.0", "0.8.0", "0.8.1"],
            "wit-bindgen": ["0.43.0", "0.46.0", "0.48.1", "0.49.0"],
            "wkg": ["0.11.0", "0.12.0", "0.13.0"],
            "wasmsign2": ["0.2.6"],
        },
    }

    if "wasm-tools" in tools_config:
        wasm_tools_version = tools_config["wasm-tools"]
        if wasm_tools_version in compatibility_matrix:
            compat_info = compatibility_matrix[wasm_tools_version]

            for tool, version in tools_config.items():
                if tool != "wasm-tools" and tool in compat_info:
                    if version not in compat_info[tool]:
                        warnings.append(
                            "Warning: {} version {} may not be compatible with wasm-tools {}. " +
                            "Recommended versions: {}".format(
                                tool,
                                version,
                                wasm_tools_version,
                                ", ".join(compat_info[tool]),
                            ),
                        )

    return warnings

def get_recommended_versions(stability = "stable"):
    """Get recommended tool versions for a given stability level

    Args:
        stability: Stability level ("stable" or "latest")

    Returns:
        Dict: Mapping of tool names to recommended versions
    """

    # Define default versions (sourced from tool_versions.bzl)
    default_versions = {
        "stable": {
            "wasm-tools": "1.239.0",
            "wac": "0.8.1",
            "wit-bindgen": "0.46.0",
            "wkg": "0.11.0",
            "wasmsign2": "0.2.6",
            "nodejs": "18.19.0",
            "jco": "1.4.0",
        },
        "latest": {
            "wasm-tools": "1.239.0",
            "wac": "0.8.1",
            "wit-bindgen": "0.46.0",
            "wkg": "0.11.0",
            "wasmsign2": "0.2.6",
            "nodejs": "18.19.0",
            "jco": "1.4.0",
        },
    }

    if stability not in default_versions:
        fail("Unknown stability level: {}. Available: {}".format(
            stability,
            ", ".join(default_versions.keys()),
        ))

    return default_versions[stability]
