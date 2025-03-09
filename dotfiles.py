import argparse
import csv
import itertools
import os
import shutil
import sys
from os.path              import expanduser, abspath, isfile, islink, isdir, dirname
from pydantic.dataclasses import dataclass
from rich                 import box
from rich                 import print
from rich.console         import Console
from rich.table           import Table
from rich_argparse        import RichHelpFormatter
from typing               import Union, Optional

CONFIG = "./configurations.csv"

RichHelpFormatter.group_name_formatter = str.upper
RichHelpFormatter.styles["argparse.groups"] = "bold salmon1"
RichHelpFormatter.styles["argparse.metavar"] = "grey50"
RichHelpFormatter.styles["argparse.prog"] = "bold sea_green1"

@dataclass
class default_config:
  name: str = ""
  source: str = ""
  destination: str = ""
  source2: str | None = None
  destination2: str | None = None


def full_path(path):
  return abspath(expanduser(path))

def config_init():
  config_list = []
  with open(CONFIG) as csvfile:
    reader = csv.reader(csvfile)
    i = 0
    for row in reader:
      config_list.append(default_config())
      config_list[i].name         = row[0]
      config_list[i].source       = row[1]
      config_list[i].destination  = row[2]
      config_list[i].source2      = row[3]
      config_list[i].destination2 = row[4]
      i = i + 1
  return sorted(config_list, key=lambda x: x.name)

def write_config(config_list):
  with open(CONFIG, 'w') as csvfile:
    for x in config_list:
      csvfile.write(f"{x.name},{x.source},{x.destination},{x.source2},{x.destination2}\n")

def add_config(name, source, destination, source2, destination2):
  with open(CONFIG, 'a') as csvfile:
    csvfile.write(f"{name},{source},{destination},{source2},{destination2}\n")

def split_list(config_list):
  full_names          = []
  installed           = []
  installed_names     = []
  not_installed       = []
  not_installed_names = []
  for config in config_list:
    if islink(full_path(config.destination)):
      installed.append(config)
      installed_names.append(config.name)
    else:
      not_installed.append(config)
      not_installed_names.append(config.name)
    full_names.append(config.name)
  return installed, not_installed, installed_names, not_installed_names, full_names

def install_config(names):
  for name in names:
    if not name in not_installed_names:
      print(f"Either [bold red]{name}[/bold red] does not exist or not found...")
      sys.exit(1)
    for x in not_installed_list:
      if name == x.name:
        try:
          os.makedirs(dirname(full_path(x.destination)), exist_ok=True)
          if isfile(full_path(x.destination)):
            print(f"File found at [bold cyan]{x.destination}[/bold cyan], removing...")
            os.remove(full_path(x.destination))
          print(f"Symbolic linking [bold blue]{x.source}[/bold blue] -> [bold cyan]{x.destination}[/bold cyan]")
          os.symlink(full_path(x.source), full_path(x.destination))
        except Exception as e:
          print(f"Error installing [bold red]{x.name}[/bold red]. Go fix it. \n [bold red]{e}[/bold red]")
          sys.exit(1)
        if not x.destination2 == "":
          try:
            os.makedirs(dirname(full_path(x.destination2)), exist_ok=True)
            if isfile(full_path(x.destination2)):
              print(f"File found at [bold cyan]{x.destination}[/bold cyan], removing...")
              os.remove(full_path(x.destination2))
            print(f"Symbolic linking [bold blue]{x.source2}[/bold blue] -> [bold cyan]{x.destination2}[/bold cyan]")
            os.symlink(full_path(x.source2), full_path(x.destination2))
          except Exception as e:
            print(f"Error installing [bold red]{x.name}[/bold red]. Go fix it. \n [bold red]{e}[/bold red]")
            sys.exit(1)

def remove_config(names):
  for name in names:
    if not name in installed_names:
      print(f"Either [bold red]{name}[/bold red] does not exist or not found...")
    for x in installed_list:
      if name == x.name:
        try:
          print(f"Removing {x.destination}")
          os.remove(full_path(x.destination))
        except Exception as e:
          print(f"[bold red]{e}[/bold red]")
          sys.exit(1)
        try:
          if not x.destination2 == "":
            print(f"Removing {x.destination2}")
            os.remove(full_path(x.destination2))
        except Exception as e:
          print(f"[bold red]{e}[/bold red]")
          sys.exit(1)

def delete_config(names):
  remove_config(names)
  for name in names:
    if not name in full_names:
      print(f"Either [bold red]{name}[/bold red] does not exist or not found...a")
      sys.exit(1)
    print("Are you sure you want to [bold]delete[/bold]?")
    response = input("Type 'delete' to confirm: ")
    if response.lower() == "delete":
      for x in full_config_list:
        if name == x.name:
          try:
            full_config_list.remove(x)
            print(f"Deleting {x.source}")
            if isfile(full_path(x.source)):
              os.remove(full_path(x.source))
            elif isdir(full_path(x.source)):
              shutil.rmtree(full_path(x.source))
            if not x.source2 == "":
              print(f"Deleting {x.source2}")
              if isfile(full_path(x.source2)):
                os.remove(full_path(x.source2))
              elif isdir(full_path(x.source2)):
                shutil.rmtree(full_path(x.source2))
          except Exception as e:
            print(f"Error deleting [bold red]{x.name}[/bold red]. Go fix it. \n [bold red]{e}[/bold red]")
            sys.exit(1)
      write_config(full_config_list)
    else:
      print("Canceling...")
      sys.exit(0)

full_config_list = config_init()
write_config(full_config_list)
installed_list, not_installed_list, installed_names, not_installed_names, full_names = split_list(full_config_list)

parser = argparse.ArgumentParser("dotfiles_installer", formatter_class=RichHelpFormatter)
parser.add_argument("-l", "--list", help="List configs", action="store_true")
manage = parser.add_argument_group(title="Manage")
manage.add_argument("-i", "--install", help="Install configs", nargs="+")
manage.add_argument("-r", "--remove", help="Remove configs", nargs="+")
modify = parser.add_argument_group(title="Add/Delete")
mutual = modify.add_mutually_exclusive_group()
mutual.add_argument("-a", "--add", help="Add new configs (3 vars)", nargs=3, metavar=("NAME", "SOURCE", "DESTINATION"))
mutual.add_argument("-ae", "--add-extra", help="Add new configs (5 vars)", nargs=5, metavar=("NAME", "SOURCE", "DESTINATION", "SOURCE2", "DESTINATION2"))
modify.add_argument("-d", "--delete", help="Delete configs", nargs="+")
args = parser.parse_args()

if args.install:
  install_config(args.install)
elif args.remove:
  remove_config(args.remove)
elif args.list:
    list_installed = []
    list_not_installed = []
    for x in installed_list:
        list_installed.append(x.name)
    for x in not_installed_list:
        list_not_installed.append(x.name)
    console = Console()
    table = Table(show_header=True)
    table.row_styles = ["none", "dim"]
    table.box = box.SIMPLE
    table.add_column("[bold green]Installed")
    table.add_column("[bold red]Not Installed")
    for x, y in itertools.zip_longest(list_installed, list_not_installed):
      table.add_row(x, y)
    console.print(table)
elif args.add:
  name, source, destination = args.add
  source2 = ""
  destination2 = ""
  add_config(name, source, destination, source2, destination2)
elif args.add_extra:
  name, source, destination, source2, destination2 = args.add_extra
  add_config(name, source, destination, source2, destination2)
elif args.delete:
  delete_config(args.delete)
else:
  parser.print_help()
