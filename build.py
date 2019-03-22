#!/usr/bin/python
import sys
import os
import glob
import pyperclip

from jinja2 import Environment, FileSystemLoader

SOURCE_DIR = './src'
ENVIRONMENTS = './environments/*.lua'

def update_context(jinja2_env, file, context):
  text = render(jinja2_env, file, context)
  filename = os.path.basename(file)
  name, ext = os.path.splitext(filename)
  context[name] = format().format(filename, text, filename)
  return context


def format():
  return '--==== START {0} ====--' + os.linesep + '{1}' + os.linesep + '--==== END {2} ====--'


def render(jinja2_env, file, context):
  tpl = jinja2_env.get_template(file)
  return tpl.render(context)


def put_environments(jinja2_env, file, context):
  text = render(jinja2_env, file, context)
  context['ENVIRONMENT'] = format().format('ENVIRONMENT', text, 'ENVIRONMENT')
  return context


def find_all_dirs(directory):
  for root, dirs, files in os.walk(directory):
    if os.path.isdir(root):
      yield root
    for file in files:
      if os.path.isdir(file):
        yield os.path.join(root, file)

def get_files():
  files = []
  for dir in find_all_dirs(SOURCE_DIR):
    files = files + glob.glob(dir + os.path.sep + '*.lua')
  return sorted(files, reverse=True, key=lambda file: len(file))  



def build(main_file, dest_dir):

  jinja2_env = Environment(loader=FileSystemLoader('./', encoding='utf-8'), variable_start_string='--{{')
  tpl = jinja2_env.get_template(main_file)
  files = get_files()
  context = {}
  for file in files:
    context = update_context(jinja2_env, file.replace(os.path.sep, '/'), context)

  for file in glob.glob(os.path.dirname(main_file) + ENVIRONMENTS):
    build_by_environment_file(jinja2_env, context, dest_dir, main_file, file)


def build_by_environment_file(jinja2_env, context, dest_dir, main_file, env_file):
  context = put_environments(jinja2_env, env_file.replace(os.path.sep, '/'), context)
  text = render(jinja2_env, main_file, context)
  base, ext = os.path.splitext(os.path.basename(main_file))
  suffix, ext = os.path.splitext(os.path.basename(env_file))
  format = '{0}' + os.path.sep + '{1}-{2}.lua'
  dest = format.format(dest_dir, base, suffix)
  with open(dest, 'wt', encoding="utf-8") as out:
    out.write(text)

  args = sys.argv
  if len(args) >= 2 and suffix == args[1]:
    pyperclip.copy(text)



def main():

  # ./main/{ビークル種別} 直下のファイルは大まかなビークル種別毎（船と飛行機等）のメインファイルを配置する。メインファイル内でインポートするファイルを変える事で、ビークル種別毎の実装を大きく変える為に使用する。
  # ./main/{ビークル種別}/enviroments 以下は個々のビークル毎の環境定義に使用する。
  # ビルド後の成果物は ./dest 以下に {ビークル種別}-{ビークル名}.lua ファイルとして出力される
  # 
  files = glob.glob('./main/*/*.lua')
  dir = './dest'
  os.makedirs(dir, exist_ok=True)
  for file in files:
    build(file.replace(os.path.sep, '/'), dir)


if __name__ == '__main__':
  main()
