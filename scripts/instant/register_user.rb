#!/usr/bin/env ruby
# -*- coding: utf-8 -*-

require 'digest/sha1'
require 'mysql2'

DATABASE_NAME = "yabitz_member_source"
TABLE_NAME = "list"

# id          INT PRIMARY KEY NOT NULL AUTO_INCREMENT,
# name        VARCHAR(64)     NOT NULL UNIQUE KEY,
# passhash    VARCHAR(40)     NOT NULL,
# fullname    VARCHAR(64)     NOT NULL,
# mailaddress VARCHAR(256)    ,
# badge       VARCHAR(16)     ,
# position    VARCHAR(16)     ,

def show_pronpt(pronpt, shadow_input=false)
  print pronpt
  system "stty -echo" if shadow_input
  input = $stdin.gets.chomp
  if shadow_input
    system "stty echo"
    puts ""
  end
  input
end

def error_exit(msg)
  puts msg
  exit
end

db_hostname = ARGV[0]
db_username = ARGV[1]
db_password = nil
if ARGV[2] == '-p'
  db_password = show_pronpt("DB password: ", true)
end

def check_username_exists(conn, username)
  username = conn.escape(username)
  result = conn.query("SELECT count(*) FROM #{TABLE_NAME} WHERE name='#{username}'").first['count(*)']
  return result > 0
end

def insert_user_record(conn, username)
  puts "ユーザデータを新規作成します"

  pass1st = show_pronpt("パスワードを入力してください: ", true)
  pass2nd = show_pronpt("パスワードをもう一度入力してください: ", true)
  error_exit "入力されたパスワードが一致しません" unless pass1st == pass2nd

  fullname = show_pronpt("氏名: ")
  error_exit "氏名は64文字までしか登録できません" if fullname.length > 64
  fullname = username if fullname.empty?

  mailaddress = show_pronpt("メールアドレス(省略可): ")
  badge = show_pronpt("社員番号(省略可): ")
  position = show_pronpt("役職(省略可): ")
  
  username = conn.escape(username)
  passhash = Digest::SHA1.hexdigest(pass1st)
  fullname = conn.escape(fullname)
  mailaddress = conn.escape(mailaddress)
  badge = conn.escape(badge)
  position = conn.escape(position)
  sql = "INSERT INTO #{TABLE_NAME} SET name='#{username}',passhash='#{passhash}',fullname='#{fullname}',mailaddress='#{mailaddress}',badge='#{badge}',position='#{position}'"
  conn.query(sql)
end

def change_user_record(conn, username)
  puts "既存のユーザデータを更新します"

  password = show_pronpt("現在のパスワードを入力してください: ", true)

  u = conn.escape(username)
  p = Digest::SHA1.hexdigest(password)
  result = conn.query("SELECT count(*) FROM #{TABLE_NAME} WHERE name='#{u}' AND passhash='#{p}'").first['count(*)']

  error_exit "パスワードが間違っています" if result != 1
  
  result = conn.prepare("SELECT fullname,mailaddress,badge,position FROM #{TABLE_NAME} WHERE name='#{u}' AND passhash='#{p}'").first
  x_fullname, x_mailaddress, x_badge, x_position = result

  pass1st = show_pronpt("パスワードを変更する場合は入力してください: ", true)
  if pass1st.length > 0
    pass2nd = show_pronpt("パスワードをもう一度入力してください: ", true)
    error_exit "入力されたパスワードが一致しません" unless pass1st == pass2nd
  else
    pass1st = password
  end

  fullname = show_pronpt("氏名 [#{x_fullname}]: ")
  error_exit "氏名は64文字までしか登録できません" if fullname.length > 64
  fullname = x_fullname if fullname.empty?

  mailaddress = show_pronpt("メールアドレス [#{x_mailaddress}]: ")
  mailaddress = x_mailaddress if mailaddress.empty?
  badge = show_pronpt("社員番号 [#{x_badge}]: ")
  badge = x_badge if badge.empty?
  position = show_pronpt("役職 [#{x_position}]: ")
  position = x_position if position.empty?

  px = Digest::SHA1.hexdigest(pass1st)
  fx = conn.escape(fullname)
  mx = conn.escape(mailaddress)
  bx = conn.escape(badge)
  pox = conn.escape(position)
  conn.query("UPDATE #{TABLE_NAME} SET passhash='#{px}',fullname='#{fx}',mailaddress='#{mx}',badge='#{bx}',position='#{pox}' WHERE name='#{u}'")
end

conn = Mysql2::Client.new(:host => db_hostname, :username => db_username, :password => db_password, :database => DATABASE_NAME)

username = show_pronpt("ユーザ名を入力してください: ")
if check_username_exists(conn, username)
  change_user_record(conn, username)
else
  insert_user_record(conn, username)
end
