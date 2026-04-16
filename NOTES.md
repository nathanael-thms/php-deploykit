# Notes

These notes are for anybody who is interested in adding to the project.

## Practices for each script

- Each script should start with the following, the last line must be changed accordingly to point to common.sh, run.sh being the only exception:
```bash
#!/bin/bash
set -euo pipefail

# Load shared utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"
```

- Every script should be possible to run through run.sh(Note: script does not have to be executable, run.sh will call it with `bash script.sh`).

- For almost all scripts, you will want to activate logging if it is enabled in the .env file. To do this, simply add the following line(note: requires shared utils to be loaded):
```bash
activate_logging "first"
```
If the script is called from another(note: Not run.sh), omit the first

- All scripts completed successfully must have the word "successfully" in the last printed line, so that the view_logs.sh can scan it for success or failure. For example, the last line of a successful deployment might be:
```bash
echo "Deployment completed successfully."
```

Case does not matter.