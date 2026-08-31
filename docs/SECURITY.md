# Security notes

- Do not commit production `modeN.json` files unless every credential has been removed.
- Do not commit UUIDs, passwords, subscription URLs, Reality private keys, WireGuard private keys, SSH private keys, API tokens or cookies.
- LuCI administrators can read/edit mode JSON through this plugin; only trusted administrators should have LuCI access.
- Configuration exports are private data even though SSH keys are excluded by default. Store exports like passwords.
- `modeN-ipv6-block.json` is generated data. Edit the base `modeN.json` only.
- After moving to a new router, verify IPv4, IPv6 and DNS egress before relying on the device for privacy-sensitive traffic.
