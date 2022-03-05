#!/usr/bin/env python

import argparse
import defs


def parse_arguments():
	parser = argparse.ArgumentParser(description=defs.DESCRIPTION, prog=defs.PROGRAM,  fromfile_prefix_chars='@')
	parser.add_argument('--sql', default=1, type=int, choices=[0, 1], help='SQL State to be set')
	parser.set_defaults(text=True)
	args, unknown = parser.parse_known_args()
	return args

def main():
	args=parse_arguments()
	if args.sql:
		if (args.sql == 1):
			print("change_sql.py = High")
			
	elif (args.sql == 0):
		print("change_sql.py = Low")



if __name__ == "__main__":
	try:
		main()
	except KeyboardInterrupt: # Ctrl C and Ctrl Z functionality
		pass