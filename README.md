# Repo for Technicolor gateway firmware extracted

# Navigate in deatached branches named as the extracted pushed firmware


### master branch cointain the `python` script used to extract these firmware ([thanks](https://repository.ilpuntotecnico.com/files/Ansuel/Script%20Decrypt%20Firmware%20RBI/)):

What the script do:
- Search for .rbi files in the same folder
- Decrypt using hardcoded keys
- Extract with unsquashfs (on macOS it automatically uses a temporary case-sensitive APFS volume, otherwise files differing only by case, like xt_DSCP.ko/xt_dscp.ko, overwrite each other)
- Verify the extraction is complete (unsquashfs inode count vs extracted entries) before pushing; if incomplete the .rbi/.bin are kept
- create a git deatached branch
- push all extracted files to the hardcoded repo
- delete all, including .rbi file
- `--no-push` skips the git push, `--keep` keeps the extracted files

## Setup virtual env
```
virtualenv venv
source venv/bin/activate
pip install -r requirements.txt
```
unsquashfs (squashfs-tools >= 4.4, with xz support) must be available in PATH:
```
brew install squashfs
```
## Run
```python
python main.py
```
