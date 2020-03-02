#!/usr/bin/env python3
# -*- coding: utf-8 -*-

import sys, struct, zlib
from git import Repo
import glob, os, shutil
from cryptography.hazmat.primitives.ciphers import Cipher, algorithms, modes
from cryptography.hazmat.backends import default_backend
import binwalk

try:			
	assert sys.version_info >= (3,0)
except AssertionError:
	print("Questo script necessita di python 3.x per funzionare")
	sys.exit(1)

osck_list = {
	"VANT-6":b'\x54\x62\x59\xAF\xD4\xE8\x5A\xA6\xFF\xCE\x35\x8C\xE0\xA9\x34\x52\xE2\x5A\x84\x81\x38\xA6\x7C\x14\x2E\x42\xFE\xC7\x9F\x4F\x37\x84',
	"VANT-9":b'\x89\xBC\xC0\x9E\xAB\xE2\x1F\xA7\x38\xE6\x2E\x6D\x91\x1F\xA8\x0C\xAF\x09\x12\x33\xEC\xCF\xF8\x84\x42\xFA\xA5\xD7\xAF\x65\x1A\x30',
	"VANT-F":b'\x7F\xA2\xFD\xF4\xD4\xDC\x31\xBF\x66\xF9\x1D\xDA\x9A\x3E\x87\x77\xB7\xD7\xD2\xEC\x6E\x8D\xB1\x92\x6C\x08\x31\xCA\x2A\x27\x9F\xDB',
	"VANT-R":b'\x39\x5A\x2C\x3E\x26\x18\xCF\x47\x7A\xA9\xAD\x68\x6F\xB0\x01\xF8\x6B\x06\xFC\x34\x75\xFA\x7F\x28\x35\x89\x01\x7D\x70\xDB\xA0\xBE',
	"VANT-Y":b'\x8E\x07\x11\x1F\x18\x86\x41\x94\x8E\x84\x50\x6D\xB6\x52\x70\xBD\x26\x59\x5A\xD4\x13\x27\x23\x5A\x53\x99\x8D\xB0\x68\xDC\x38\x33',
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
	"VDNT-O":b'\xEF\xA9\x26\x8D\x14\x55\xDF\x20\xE8\xF7\x30\x84\xE5\xD6\x7F\x3D\x3B\x91\x96\x16\x80\xE5\x47\x32\x17\x8B\xD7\xEC\x5D\x94\xAA\xC3',
	"VDNT-W":b'\xAA\x72\x20\xBC\x88\x32\x9A\xCF\x74\xA0\x42\xB4\xD4\x5B\x07\xB1\x65\x61\x5B\x10\x91\x6C\xF4\x0B\x0B\xCC\x86\x08\xBE\x9E\x1D\x60',
}

def decrypt( file ):
	
	datafile = open( file, "rb")
	globalheader = datafile.read(0x144)
	board_name = struct.unpack_from(">6s", globalheader, 0x13c)[0].decode('ascii')
	if board_name in osck_list:
		osck=osck_list[board_name]
	else:
		print("No OSCK for board: "+board_name)
		exit(1)
	payloadstart = struct.unpack_from(">H", globalheader, 0x2A)[0]
	datafile.seek(payloadstart)
	data = datafile.read()
	
	while True:
		payloadtype = data[0]
		if payloadtype == 0xB0: # in chiaro
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
	
	output_name = file[:(file.find("rbi"))]+"bin" #rimuove estensione rbi
	output_file = open(output_name,"w+b") #crea il bin
	output_file.write(data) #Scrive i dati
	
	print("Decrypted:",output_name)
	return output_name

		
os.chdir("./")
for file in glob.glob("*.rbi"):
	print("Decrypting %s..."%file)
	dec_filename=decrypt(file)
	print("Binwalking %s..."%dec_filename)
	path_to_push=''
	for module in binwalk.scan(dec_filename, signature=True, extract=True, quiet=True):
		for result in module.results:
			if result.file.path in module.extractor.output:
				if result.offset in module.extractor.output[result.file.path].extracted:
					if 'root' in module.extractor.output[result.file.path].extracted[result.offset].files[0]:
						path_to_push=module.extractor.output[result.file.path].extracted[result.offset].files[0]
						print("Found rootfs %s"%path_to_push)
					#print("Extracted %d files from offset 0x%X to '%s' using '%s'" % (len(module.extractor.output[result.file.path].extracted[result.offset].files),result.offset,module.extractor.output[result.file.path].extracted[result.offset].files[0],module.extractor.output[result.file.path].extracted[result.offset].command))
	if path_to_push != '':
		print("Pushing to github...")
		repo = Repo.init(path_to_push) #create repo object of the other repository
		repo.create_remote('origin', 'https://github.com/FrancYescO/tch_firmware_extracted')
		repo.remotes[0].fetch()
		branch_name=dec_filename[:(dec_filename.find(".bin"))]
		repo.git.checkout('-b', branch_name)
		repo.git.add('.') # same as git add file
		repo.git.commit(m = branch_name) # same as git commit -m "commit message"
		repo.git.push('origin', branch_name) # git push remote_to_push HEAD:master
	print("Cleaning...")
	shutil.rmtree('_'+dec_filename+'.extracted')
	os.remove(file)
	os.remove(dec_filename)
