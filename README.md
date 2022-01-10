# Repo for Technicolor gateway firmware extracted

# Navigate in deatached branches named as the extracted pushed firmware


### master branch cointain the `python` script used to extract these firmware ([thanks](https://repository.ilpuntotecnico.com/files/Ansuel/Script%20Decrypt%20Firmware%20RBI/)):

What the script do:
- Search for .rbi files in the same folder
- Decrypt using hardcoded keys
- Unpack using binwalk
- create a git deatached branch
- push all extracted files to the hardcoded repo
- delete all, including .rbi file

## Setup virtual env
```
virtualenv venv
source venv/bin/activate
pip install -r requirements.txt
git clone https://github.com/ReFirmLabs/binwalk.git
cd binwalk
sudo python setup.py install
```
## Run
```python
python main.py
```
