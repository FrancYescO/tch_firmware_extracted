#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, struct, zlib, subprocess, re
import glob, os, shutil
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend

try:
	assert sys.version_info >= (3,0)
except AssertionError:
	print("Questo script necessita di python 3.x per funzionare")
	sys.exit(1)

osck_list = {
	"DANT-7":b'\xA5\x68\xCB\xE5\x70\x60\xA8\xF6\xE5\xEC\xA4\xE5\xC8\xCB\x7C\xEB\x09\xFC\xE0\xA0\xD1\x20\x20\xF4\xB2\x58\x40\x4B\x04\x92\x70\x53',
	"GANT-1":b'\x03\x73\x85\x33\x14\xB4\x86\xE3\x35\xE4\x64\xB3\x87\x2E\x56\x39\x66\x34\xDF\xD5\xB6\xDB\x9B\xD0\x3A\x3D\xFA\xDE\x0E\x37\x14\x6D',
	"VANT-2":b'\xB0\xE8\x82\x49\xB1\x50\xC9\x34\xAC\x2B\xA3\x5E\x7A\x7C\x71\x2B\x32\x44\x83\x3E\xD8\xDA\x10\xAB\xAB\x5D\xAA\x91\xAE\x9F\x45\x5F',
	"VANT-6":b'\x54\x62\x59\xAF\xD4\xE8\x5A\xA6\xFF\xCE\x35\x8C\xE0\xA9\x34\x52\xE2\x5A\x84\x81\x38\xA6\x7C\x14\x2E\x42\xFE\xC7\x9F\x4F\x37\x84',
	"VANT-9":b'\x89\xBC\xC0\x9E\xAB\xE2\x1F\xA7\x38\xE6\x2E\x6D\x91\x1F\xA8\x0C\xAF\x09\x12\x33\xEC\xCF\xF8\x84\x42\xFA\xA5\xD7\xAF\x65\x1A\x30',
	"VANT-F":b'\x7F\xA2\xFD\xF4\xD4\xDC\x31\xBF\x66\xF9\x1D\xDA\x9A\x3E\x87\x77\xB7\xD7\xD2\xEC\x6E\x8D\xB1\x92\x6C\x08\x31\xCA\x2A\x27\x9F\xDB',
	"VANT-R":b'\x39\x5A\x2C\x3E\x26\x18\xCF\x47\x7A\xA9\xAD\x68\x6F\xB0\x01\xF8\x6B\x06\xFC\x34\x75\xFA\x7F\x28\x35\x89\x01\x7D\x70\xDB\xA0\xBE',
	"VANT-W":b'\xB2\x20\x34\x6F\x6C\xCC\x90\x35\x45\xA1\xFD\xB4\x58\xAA\xE8\x24\x8A\x4B\xF7\x78\x60\x31\xD4\xD0\xA3\x3E\xCB\x31\xBB\x23\x7F\xD0',
	"VANT-W_telia":b'\x44\x63\xC4\xC3\x3F\xE7\x88\xB3\xCD\x2B\xD4\x08\x70\x6B\xDF\x07\x79\x9D\x48\x73\xA7\xD5\x0D\x65\xDB\x20\x5C\xF6\x5E\x34\xF8\x7E',
	"VANT-Y":b'\x8E\x07\x11\x1F\x18\x86\x41\x94\x8E\x84\x50\x6D\xB6\x52\x70\xBD\x26\x59\x5A\xD4\x13\x27\x23\x5A\x53\x99\x8D\xB0\x68\xDC\x38\x33',
	"VBNT-1":b'\xC6\x16\x69\xDB\x31\x7E\x14\xBB\x28\xF1\x80\xE8\xB2\xB2\xF7\x8E\xD4\xF6\x54\xDE\x4D\x2E\x53\x06\x9C\x87\xB5\x5C\xED\x84\x0A\x16',
	"VBNT-F":b'\xFC\xD9\xBE\x1D\x6D\x8E\xA6\x59\x68\xE7\x7A\x89\xB8\xAF\xCA\x98\xA1\x46\x7F\xEE\xE8\x7A\x87\xBD\x27\x6C\x91\xDD\x94\xD4\x1D\x59',
	"VBNT-H":b'\x7E\xA0\xFF\xCC\xE7\xB0\x79\xAC\x08\x79\x2A\x7C\x78\x99\xAE\xC9\x0D\x01\x3B\xA2\x57\x4A\x41\x46\x55\x02\xE6\x2B\x9E\xBD\x55\x88',
	"VBNT-J":b'\x22\x2C\x4D\xC4\xA9\xDF\x95\x2B\x02\xD5\xA4\x89\xA1\x12\xCF\x5E\x29\xAA\xED\xF8\x6A\xDB\x63\x44\x10\xD6\x72\x1F\x15\xF4\x51\xE4',
	"VBNT-K":b'\xFF\xD5\x6A\x4E\x3A\x21\x40\x1B\xF1\x79\x8B\x3C\xD8\xAD\x54\xD2\x38\xBA\x80\x03\x96\x23\xBB\xA0\x8B\x6D\x50\xB8\xEC\x73\xF7\xB4',
	"VBNT-L":b'\xA4\x84\x24\x5C\xCF\xBE\x25\x41\xB0\xC5\xC5\xE9\x23\xBE\x67\xA7\xDE\xB9\xA8\x23\xDD\x5C\xBA\xB9\x2C\xC6\x19\xDE\xA1\x39\x1A\x42',
	"VBNT-O":b'\x91\x6A\xEB\x56\x9D\x8C\xBF\x8C\xFA\xF0\x60\xAE\xC5\x33\xD4\x3A\x9E\xF0\xAC\xB3\x13\x8F\x83\x51\xC4\x11\x26\x74\x21\x29\x75\xA5',
	"VBNT-S":b'\x0E\xF3\x4D\x97\x29\x45\x86\x9E\xF4\x0F\x89\x87\x3F\xED\x30\x26\x90\x20\xE1\x07\x68\x5C\x09\x77\x51\xBE\xF9\x47\x9D\x75\xD6\x20',
	"VBNT-V":b'\x7B\xFF\xB7\xEB\xBE\x41\x6D\x38\x07\x87\x12\xEC\x5A\xC5\xDE\xF6\xE4\xE5\x0E\xE5\x88\x48\xD6\xF2\xC0\x72\xDF\x6E\x0C\x6C\xEF\xE7',
	"VBNT-Z":b'\xBA\x6B\x79\xCA\xAC\xF7\xA7\x40\xAC\xF3\x66\xAB\x11\xDA\xAA\x3E\x48\x25\x2B\xD9\x72\x05\xAC\x6D\x07\xC5\x58\xCD\xDA\x5E\xD7\xCC',
	"VCNT-A":b'\xAD\x8A\x87\xE2\x9B\xE6\xB6\xED\x72\xF5\x75\xC1\xC8\x0B\xBD\x63\x8E\x7C\xE9\x5E\x5B\xF9\x82\x41\x45\xFD\x7D\x04\x2C\xDA\x2D\x79',
	"VDNT-O":b'\x7C\xDC\x61\x99\x3A\x2F\xAE\xF6\x40\x33\x70\x55\x15\xAF\xE8\xB1\x52\xFB\x4B\x1A\xF0\xB1\x29\xF7\xE9\x1C\x63\xC5\xD3\xFE\xB6\x99',
	"VDNT-W":b'\xAA\x72\x20\xBC\x88\x32\x9A\xCF\x74\xA0\x42\xB4\xD4\x5B\x07\xB1\x65\x61\x5B\x10\x91\x6C\xF4\x0B\x0B\xCC\x86\x08\xBE\x9E\x1D\x60',
	"VCNT-3":b'\xAF\xE6\xA9\x28\xEF\xD1\xD5\x82\x4C\xCA\x03\xCF\x6F\x9C\xD7\x79\x6F\xCB\xE9\xA7\x46\xAA\x71\x20\x79\x2B\x66\x6F\xC2\xC3\xEB\xB6',
	"GCNT-N":b'\xC4\x41\x70\x5B\xCE\x53\x9C\x13\x00\x16\xE8\xF9\x7B\x6A\x95\xE6\x27\xB9\x48\x76\x0A\x4A\x3E\x5F\x1C\xC3\xF3\x52\x39\x2B\x38\x9A',
	"GBNT-2":b'\xF1\xC7\xF7\x09\xC3\xD8\x94\x30\x2C\x2F\x84\x54\x55\x3E\x44\x8D\xF4\x2A\xDC\x99\x98\x1E\x59\x3B\xBF\x4D\xB3\xB8\x7C\xAF\x9F\x5B',
	"DANT-8":b'\x04\xDF\x07\x35\x1D\x6A\xD9\xEE\xA1\x4E\xA4\x3E\x42\xD1\xE8\xCD\x2F\x57\x5A\x92\x41\xAD\xBE\xEA\x45\x44\x4D\x30\x60\xA6\x54\x26',
	"GANT-K":b'\xA2\x22\x2F\x1D\x74\x9B\xC2\x6A\xD0\xA7\xBC\xAB\x38\xCA\xF3\x8D\x48\xC9\x80\x78\x1F\x44\x12\xF4\xE8\x7F\xED\x73\x8C\xBF\x1E\x4A',
	"GCNT-R":b'\x6D\xA9\x9A\x3E\x67\x87\x99\x4C\x11\x7B\x5A\x1A\x4B\xF0\x7A\x09\xB7\x91\x63\x11\x76\x46\x85\x05\x02\x6A\x2D\x7E\xDA\xA8\x02\x8C',
	"VANT-8":b'\x8F\x12\x37\xF2\x43\x03\xAB\x00\x67\xD4\x4E\xBA\x1F\xC0\x7E\x18\x2B\xDC\x0C\x9A\xC4\x8C\x35\x2C\xF5\x81\x15\xDF\xCC\x2B\xC4\x36',
	"VBNT-2":b'\x02\xB8\x99\xA1\x4C\x88\x6F\x50\x41\xA1\xF4\xE0\x4E\xA6\x83\xC9\x6E\x7C\x96\x13\x1F\x78\xDC\x64\xF1\xE5\x8F\xF4\xAC\x53\x28\x80',
	"VCNT-2":b'\x75\x16\x53\x94\x50\xA6\x3B\x86\x70\x50\x2E\xF9\x72\xCD\xC9\xB3\x31\xB9\x9F\xB3\x94\x03\xE7\xF7\x5A\x88\xBB\x6F\xE3\x60\x2C\x52',
	"VCNT-C":b'\xF8\xF9\xC0\x4F\x89\x50\x9B\x7B\xCB\x0A\xE3\x81\x3F\x80\x3A\xDC\x36\xEE\x82\x5F\xC9\xA6\x87\xA2\x26\xBB\x78\xD2\x67\x58\x8B\x82',
	"VCNT-H":b'\x87\x97\xE3\x7E\x3F\x8C\xFB\x19\x0A\xE3\x10\x5D\x14\x3D\xC5\x86\x4D\xF9\x98\xC2\x37\x6E\xAD\x45\xD7\xC2\x9B\x74\x93\x92\x0E\xBD',
	"VCNT-J":b'\xF3\xDA\xB7\x23\xFB\x13\x83\xF0\x7D\xDB\x3A\xF6\x1C\x84\xA2\x1A\xE1\xF0\x04\xAA\x94\xFF\xCA\xBB\x1A\x8E\xFB\x7D\xA3\x23\x3E\x75',
	"VCNT-P_Telia":b'\x92\x4E\x3D\x4E\x2C\x45\x6E\x02\xC2\x48\x85\x4F\xCA\x15\xC6\x84\x1A\x40\x67\x31\xE3\xD7\xE9\x61\xA3\xB9\x6A\x8B\x61\xA8\x66\x77',
	"VDNT-O_Telia":b'\x7C\xDC\x61\x99\x3A\x2F\xAE\xF6\x40\x33\x70\x55\x15\xAF\xE8\xB1\x52\xFB\x4B\x1A\xF0\xB1\x29\xF7\xE9\x1C\x63\xC5\xD3\xFE\xB6\x99',
}

def decrypt( file ):
	try:
		datafile = open( file, "rb")
		globalheader = datafile.read(0x144)
		board_name = struct.unpack_from(">6s", globalheader, 0x13c)[0].decode('ascii')
		if board_name in osck_list:
			osck=osck_list[board_name]
		else:
			print("No OSCK for board: "+board_name)
			return None
		payloadstart = struct.unpack_from(">H", globalheader, 0x2A)[0]
		datafile.seek(payloadstart)
		data = datafile.read()

		while True:
			payloadtype = data[0]
			if payloadtype == 0xB0: # plaintext
				data = data[1+4+1:]
				break
			elif payloadtype == 0xB8: # sha256
				data = data[1+4+1+4+32:]
			elif payloadtype == 0xB4: # zip
				data = zlib.decompress(data[1+4+1+4:])
			elif payloadtype == 0xB7: # aes256
				data = data[1+4+1+4:]
				iv = data[:16]
				keydata = data[16:64]
				backend = default_backend()
				cipher = Cipher(algorithms.AES(osck), modes.CBC(iv), backend=backend)
				decryptor = cipher.decryptor()
				keydata = decryptor.update(keydata) + decryptor.finalize()
				key = keydata[:-keydata[-1]]
				iv = data[64:80]
				cipher = Cipher(algorithms.AES(key), modes.CBC(iv), backend=backend)
				decryptor = cipher.decryptor()
				data = decryptor.update(data[80:]) + decryptor.finalize()
				data = data[:-data[-1]]

		output_name = file[:(file.find("rbi"))]+"bin" #remove rbi extension
		output_file = open(output_name,"w+b") #create the bin
		output_file.write(data) #write the data

		print("Decrypted:",output_name)
		return output_name
	except Exception as e:
		print("Decrypting Failed: "+str(e))


VOL_NAME="TCHXTRACT"

def fs_is_case_sensitive(path):
	test_a=os.path.join(path,"CaseSensitiveTest")
	test_b=os.path.join(path,"casesensitivetest")
	try:
		open(test_a,"w").close()
		insensitive=os.path.exists(test_b)
		os.remove(test_a)
		return not insensitive
	except OSError:
		return True

def attach_case_sensitive_volume(size="4g"):
	# on case-insensitive filesystems (default APFS on macOS) files that differ
	# only by case (e.g. xt_DSCP.ko/xt_dscp.ko) overwrite each other during the
	# extraction, so extract inside a case-sensitive sparse image
	dmg=os.path.abspath("extract_case_sensitive.sparse")
	if os.path.exists(dmg):
		os.remove(dmg)
	create=subprocess.run(["hdiutil","create","-type","SPARSE","-fs","Case-sensitive APFS","-size",size,"-volname",VOL_NAME,"-ov",dmg],capture_output=True,text=True)
	if create.returncode!=0:
		print("Cannot create case-sensitive volume: "+create.stderr)
		return None,None
	created=re.search(r"created: (.+)",create.stdout)
	if created:
		dmg=created.group(1).strip()
	attach=subprocess.run(["hdiutil","attach","-nobrowse",dmg],capture_output=True,text=True)
	if attach.returncode!=0:
		print("Cannot attach case-sensitive volume: "+attach.stderr)
		return None,None
	mountpoint=attach.stdout.strip().split("\n")[-1].split("\t")[-1].strip()
	return mountpoint,dmg

def find_rootfs(binfile):
	# find squashfs superblocks in the decrypted image and return the biggest
	# one (the rootfs) as (offset,size)
	with open(binfile,"rb") as f:
		data=f.read()
	best=None
	pos=0
	while True:
		pos=data.find(b"hsqs",pos)
		if pos<0:
			break
		major,=struct.unpack_from("<H",data,pos+0x1c)
		bytes_used,=struct.unpack_from("<Q",data,pos+0x28)
		if major==4 and 0x400<bytes_used<=len(data)-pos:
			if best is None or bytes_used>best[1]:
				best=(pos,bytes_used)
		pos+=4
	return best

def squashfs_inodes(sqsh):
	out=subprocess.run(["unsquashfs","-s",sqsh],capture_output=True,text=True).stdout
	m=re.search(r"Number of inodes (\d+)",out)
	return int(m.group(1)) if m else None

def extract_rootfs(dec_filename):
	found=find_rootfs(dec_filename)
	if not found:
		print("No squashfs found in "+dec_filename)
		return None,None,None,None
	offset,size=found
	sqsh=dec_filename+".sqsh"
	with open(dec_filename,"rb") as src,open(sqsh,"wb") as dst:
		src.seek(offset)
		dst.write(src.read(size))
	inodes=squashfs_inodes(sqsh)
	mountpoint,dmg=(None,None)
	outdir=dec_filename+".extracted"
	if sys.platform=="darwin" and not fs_is_case_sensitive("."):
		mountpoint,dmg=attach_case_sensitive_volume()
		if mountpoint:
			outdir=os.path.join(mountpoint,dec_filename+".extracted")
		else:
			print("WARNING: extracting on a case-insensitive filesystem, files differing only by case will collide")
	elif sys.platform!="darwin" and not fs_is_case_sensitive("."):
		print("WARNING: current filesystem is case-insensitive, files differing only by case will collide, run from a case-sensitive filesystem")
	print("Unsquashing %s (offset 0x%X, size %d, %s inodes)..."%(sqsh,offset,size,inodes))
	proc=subprocess.run(["unsquashfs","-no-progress","-f","-d",outdir,sqsh],capture_output=True,text=True)
	if proc.returncode!=0:
		print("unsquashfs failed: "+proc.stdout+proc.stderr)
		return None,mountpoint,dmg,sqsh
	extracted=0
	for num,kind in re.findall(r"created (\d+) (\w+)",proc.stdout):
		if kind!="hardlinks":
			extracted+=int(num)
	if inodes is None or extracted<inodes:
		print("ERROR: extraction incomplete (%d/%s inodes), keeping .rbi/.bin for debugging"%(extracted,inodes))
		return None,mountpoint,dmg,sqsh
	return outdir,mountpoint,dmg,sqsh

NO_PUSH="--no-push" in sys.argv
KEEP="--keep" in sys.argv

try:
	from git import Repo, RemoteReference
except ImportError:
	Repo=None

REPO_URL=None
remote_branches=None
if not NO_PUSH:
	if Repo is None:
		print("GitPython not installed, pushing disabled")
		NO_PUSH=True
	else:
		try:
			local_repo=Repo(".") # use the current repository's origin remote, no hardcoded URL
			REPO_URL=local_repo.remotes.origin.url
			try:
				local_repo.remotes.origin.fetch("--prune","--quiet") # best-effort: refresh refs if the network is available
			except Exception:
				pass
			remote_branches={ref.name[len("origin/"):] for ref in local_repo.refs if isinstance(ref,RemoteReference) and not ref.name.endswith("/HEAD")}
		except Exception:
			print("No origin remote found, pushing disabled")
			NO_PUSH=True

def normalize_branch(name):
	# git does not allow spaces and other characters in branch names,
	# normalization is deterministic so the filename check still works
	name=re.sub(r'[\s~^:?*\[\]\\]+','_',name)
	name=re.sub(r'\.{2,}','_',name)
	name=re.sub(r'^[./]+|[./]+$','',name)
	if name.endswith(".lock"):
		name=name[:-5]+"_"
	return name

os.chdir("./")
for file in glob.glob("*.rbi"):
	branch_name=normalize_branch(os.path.splitext(file)[0]) # filename without extension, normalized
	if remote_branches is not None and branch_name in remote_branches:
		print("Skipping %s: branch %s already exists"%(file,branch_name))
		continue
	print("Decrypting %s..."%file)
	dec_filename=decrypt(file)
	if not dec_filename:
		continue
	path_to_push,mountpoint,dmg,sqsh=extract_rootfs(dec_filename)
	if path_to_push and os.path.isdir(path_to_push):
		if not NO_PUSH:
			print("Pushing to github...")
			repo = Repo.init(path_to_push) #create repo object of the other repository
			repo.create_remote('origin', REPO_URL)
			repo.remotes[0].fetch()
			repo.git.checkout('-b', branch_name)
			repo.git.add('.') # same as git add file
			repo.git.commit(m = branch_name) # same as git commit -m "commit message"
			repo.git.push('origin', branch_name) # git push remote_to_push HEAD:master
		else:
			print("--no-push: skipping git push, extracted at "+path_to_push)
	else:
		KEEP=True
	if mountpoint:
		subprocess.run(["hdiutil","detach",mountpoint],capture_output=True)
	if dmg and not KEEP and os.path.exists(dmg):
		os.remove(dmg)
	if not KEEP:
		print("Cleaning...")
		if os.path.isdir(dec_filename+".extracted"):
			shutil.rmtree(dec_filename+".extracted")
		if sqsh and os.path.exists(sqsh):
			os.remove(sqsh)
		os.remove(file)
		os.remove(dec_filename)
