#!/usr/bin/env ruby
# encoding: utf-8
require 'bundler/setup'
require 'pathname'
require 'logger'
require 'yaml'
require 'rack'
require 'pry-byebug'
require_relative 'app/app'

App.init!

require_relative 'app/report-server'

Rack::Server.new(
  app: ReportServer.new, Host: Cfg.http.host, Port: Cfg.http.port,
  Logger: Log, Log: Log
).start


App.shutdown
