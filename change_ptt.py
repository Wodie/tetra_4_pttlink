#!/usr/bin/env python

import argparse
import defs


def parse_arguments():
	parser = argparse.ArgumentParser(description="PTT GPIO change script", prog="change_ptt.py",  fromfile_prefix_chars='@')
	parser.add_argument('--ptt', default=1, type=int, choices=[0, 1], help='PTT State to be set')
	parser.set_defaults(text=True)
	args, unknown = parser.parse_known_args()
	return args

def main():
	args=parse_arguments()
	if args.sql:
		if (args.ptt == 1):
			print("change_ptt.py = High")
	elif (args.ptt == 0):
		print("change_ptt.py = Low")

if __name__ == "__main__":
	try:
		main()
	except KeyboardInterrupt: # Ctrl C and Ctrl Z functionality
		pass