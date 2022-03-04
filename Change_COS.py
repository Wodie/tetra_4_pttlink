#!/usr/bin/env python

import argparse
import defs


def parse_arguments():
	parser = argparse.ArgumentParser(description=defs.DESCRIPTION, prog=defs.PROGRAM,  fromfile_prefix_chars='@')
	parser.add_argument('--cos', default=1, type=int, choices=[0, 1], help='COS State to be set')
	parser.set_defaults(text=True)
	args, unknown = parser.parse_known_args()
	return args

def main():
	args=parse_arguments()
	if args.cos:
		if (args.cos == 1):
			print "Change_COS.py = High"
			
	elif (args.cos == 0):
		print "Change_COS.py = Low"



if __name__ == "__main__":
	try:
		main()
	except KeyboardInterrupt: # Ctrl C and Ctrl Z functionality
		pass