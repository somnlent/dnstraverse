#!/usr/bin/env ruby

# = Summary
# Traverse the DNS from the root exploring all possible ways of
# getting to the final destination domain name.  This is the command
# line interface to DNSCheck.
#
# == Usage
# dnscheck.rb [options] DOMAIN
#    -t, --type TYPE              Select record type (A, AAAA, SRV, WKS, NS,
#                                   CNAME, SOA, PTR, HINFO, MINFO, MX, TXT, ANY)
#        --root-server HOST       Root DNS server (default - ask local resolver)
#        --[no-]all-root-servers  Find all root servers (default false)
#        --[no-]broken-roots      Use unresponsive root servers (default false)
#        --root-aaaa              Look for IPv6 addresses for root servers
#        --follow-aaaa            Only follow AAAA records for referrals
#        --[no-]allow-tcp         Try using tcp if udp truncated (default true)
#        --[no-]always-tcp        Always use tcp (default false)
#
#        --[no-]show-progress     Display progress information (default true)
#        --[no-]show-workings     Display detailed workings (default true)
#        --[no-]show-resolves     Display referral resolutions (default false)
#        --[no-]show-serverlist   Display list of servers seen (default true)
#        --[no-]show-versions     Display versions of dns servers (default true)
#        --[no-]show-summary      Display summary information (default true)
#
#    -v, --[no-]verbose           Run verbosely
#    -d, --debug                  Debug mode: One -d for DNSCheck debug
#                                             Two -d also turns on library debug
#    -h, --help                   Show full help
#    -V, --version                Show version and exit
#
# == Author
# James Ponder <james@squish.net>
#
# == Copyright
# Copyright (c) James Ponder 2008
# My use only; no license granted; do not distribute
#

def referral_txt_normal(r)
  txt = sprintf("%s %s (%s)", r.refid, r.server, r.txt_ips)
  return txt
end

def referral_txt_verbose(r)
  txt = sprintf("%s [%s] %s (%s) <%s>", r.refid, r.qname, r.server,
  r.txt_ips_verbose, r.bailiwick)
  return txt
end

def progress_main(args)
  o = args[:state]
  r = args[:referral]
  stage = args[:stage]
  return if r.refid.empty?
  case stage
    when :answer then
    if o[:verbose] then
      for warning in r.warnings do
        puts "#{r.refid} WARNING: #{warning}"
      end
    end
    if o[:allstats] then
      r.stats_display(:prefix => "#{r.refid} Results:", :results => false)
    end
    when :start then
    print o[:verbose] ? referral_txt_verbose(r) : referral_txt_normal(r)
    print "\n"
  end
end

def progress_resolves(args)
  o = args[:state]
  r = args[:referral]
  stage = args[:stage]
  case stage
    when :start then
    print o[:verbose] ? referral_txt_verbose(r) : referral_txt_normal(r)
    print "\n"
  end
end

# stdlib
require 'optparse'
require 'ostruct'
require 'logger'
###require 'resolv'
require 'rdoc/usage'
require 'pp'

# dnscheck
require 'dns_check'
require 'log'

Version = [ 0, 0, 1].freeze

options = Hash.new
options[:verbose] = false
options[:debug] = 0
options[:type] = :a
options[:root] = nil
options[:allroots] = false
options[:broken] = false
options[:progress] = true
options[:summary] = true
options[:workings] = true
options[:resolves] = false
options[:serverlist] = true
options[:versions] = true
options[:domainname] = nil
options[:follow_aaaa] = false
options[:root_aaaa] = false
options[:always_tcp] = false
options[:allow_tcp] = false
options[:allstats] = false

opts = OptionParser.new
opts.banner = "Usage: #{File.basename($0)} [options] DOMAIN"  
opts.on("-v", "--[no-]verbose") { |o| options[:verbose] = o }
opts.on("-d", "--[no-]debug") { |o| options[:debug]+= 1 }
opts.on("-r", "--root-server HOST") { |o| options[:root] = o }
opts.on("-a", "--all-root-servers") { |o| options[:allroots] = o }
opts.on("-t", "--type TYPE", Dnsruby::Types.constants) { |o| options[:type] = o }
opts.on("--allow-tcp") { |o| options[:allow_tcp] = o }
opts.on("--always-tcp") { |o| options[:always_tcp] = o }
opts.on("--[no-]broken-roots") { |o| options[:broken] = o }
opts.on("--[no-]follow-aaaa") { |o| options[:follow_aaaa] = o }
opts.on("--[no-]root-aaaa") { |o| options[:root_aaaa] = o }
opts.on("--[no-]show-progress") { |o| options[:progress] = o }
opts.on("--[no-]show-summary") { |o| options[:summary] = o }
opts.on("--[no-]show-workings") { |o| options[:workings] = o }
opts.on("--[no-]show-resolves") { |o| options[:resolves] = o }
opts.on("--[no-]show-serverlist") { |o| options[:serverlist] = o }
opts.on("--[no-]show-versions") { |o| options[:versions] = o }
opts.on("--[no-]show-all-stats") { |o| options[:allstats] = o}
opts.on_tail("-h", "--help") { RDoc::usage }
opts.on_tail("-V", "--version") { puts Version.join('.'); exit }
begin
  opts.parse!
  if ARGV.size != 1 then
    raise OptionParser::ParseError, "Missing domain name parameter"
  end
  options[:domainname] = ARGV.shift
rescue OptionParser::ParseError => e
  puts e
  RDoc::usage(1, 'Usage')
end
Log.level = options[:debug] > 0 ? Logger::DEBUG : Logger::UNKNOWN
Log.debug {"Options chosen:\n" }
Log.debug { options.map {|x,y| "  #{x}: #{y}" }.join("\n") }
args = { :state => options, :aaaa => options[:follow_aaaa] }
args[:progress_main] = method(:progress_main) if options[:progress]
args[:progress_resolve] = method(:progress_resolves) if options[:progress] and options[:resolves]
#args[:summary] = method(:summary) if options[:summary]
#args[:workings] = method(:workings) if options[:workings]
#args[:serverlist] = method(:serverlist) if options[:serverlist]
#args[:versions] = method(:versions) if options[:versions]
args[:loglevel] = options[:debug] >= 1 ? Logger::DEBUG : Logger::UNKNOWN
args[:libloglevel] = options[:debug] >= 2 ? Logger::DEBUG : Logger::UNKNOWN
args[:always_tcp] = true if options[:always_tcp]
args[:allow_tcp] = true if options[:allow_tcp]
dnscheck = DNSCheck::Resolver.new(args)
if options[:root] then
  root = options[:root]
  rootip = root # XXX fix me need to look up IP address if not passed
else
  begin
   (root, rootip) = dnscheck.get_a_root(:aaaa => options[:root_aaaa])
  rescue DNSCheck::ResolveError => e
    puts "Failed to find a root: " + e.message
    exit 2
  end
end
puts "Using #{root} (#{rootip}) as initial root"
if options[:allroots] then
  roots = dnscheck.find_all_roots(:root => root, :rootip => rootip,
                                  :aaaa => options[:root_aaaa] )
  puts "All roots:"
  for aroot in roots do
    puts "  #{aroot[:name]} #{aroot[:ips].join(', ')}"
  end
else
  roots = [ { :name => root, :ips => [ rootip ] } ]
end
puts "Running query #{options[:domainname]} type #{options[:type]}"
result = dnscheck.run_query(:qname => options[:domainname],
                            :qtype => options[:type].to_s, :roots => roots)
puts if options[:progress]
puts "Results:"
result.stats_display(:results => true, :spacing => true)
