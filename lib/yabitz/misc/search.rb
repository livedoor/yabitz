# -*- coding: utf-8 -*-

require_relative '../model'
require_relative './racktype'
require_relative '../plugin'

module Yabitz
  module DetailSearch
    def self.search_part(field, pattern_string)
      pattern = Regexp.compile(pattern_string)
      case field
      when 'service'
        pattern = Regexp.compile(pattern_string, Regexp::IGNORECASE)
        Yabitz::Model::Service.regex_match(:name => pattern, :oidonly => true).map do |srv_oid|
          Yabitz::Model::Host.query(:service => srv_oid, :oidonly => true)
        end.flatten
      when 'rackunit'
        plugins = Yabitz::Plugin.get(:racktype).select{|p| p.respond_to?(:search_extra_pattern)}
        patterns = [pattern] + plugins.map{|p| p.search_extra_pattern(pattern_string)}.flatten
        patterns.map{|p| Yabitz::Model::RackUnit.regex_match(:rackunit => Regexp.compile(p)).map(&:hosts_by_id)}.flatten.uniq
      when 'hwid'
        Yabitz::Model::Host.regex_match(:hwid => pattern, :oidonly => true)
      when 'dnsname'
        Yabitz::Model::DNSName.regex_match(:dnsname => pattern).map(&:hosts_by_id).flatten.uniq
      when 'ipaddress'
        Yabitz::Model::IPAddress.regex_match(:address => pattern).map(&:hosts_by_id).flatten.uniq
      when 'hwinfo'
        Yabitz::Model::HwInformation.regex_match(:name => pattern, :oidonly => true).map do |info_oid|
          Yabitz::Model::Host.query(:hwinfo => info_oid, :oidonly => true)
        end.flatten
      when 'os'
        Yabitz::Model::Host.regex_match(:os => pattern, :oidonly => true)
      when 'tag'
        Yabitz::Model::TagChain.query(:tagchain => pattern.source).map(&:host_by_id).uniq
      when 'status'
        Yabitz::Model::Host.regex_match(:status => pattern, :oidonly => true)
      end
    end

    def self.search(andor, conditions, ex_andor, ex_conditions)
      oidset = []
      conditions.each do |field, pattern|
        each_set = self.search_part(field, pattern)
        if oidset.size == 0
          oidset.push(*each_set)
        else
          if andor == 'AND'
            oidset = oidset & each_set
          elsif andor == 'OR'
            oidset = oidset | each_set
          else
            raise ArgumentError, "invalid and/or specification: #{andor}"
          end
        end
      end
      ex_oidset = []
      ex_conditions.each do |field, pattern|
        each_set = self.search_part(field, pattern)
        if ex_oidset.size == 0
          ex_oidset.push(*each_set)
        else
          if ex_andor == 'AND'
            ex_oidset = ex_oidset & each_set
          elsif ex_andor == 'OR'
            ex_oidset = ex_oidset | each_set
          else
            raise ArgumentError, "invalid and/or specification: #{ex_andor}"
          end
        end
      end
      oidset = oidset - ex_oidset
      Yabitz::Model::Host.get(oidset)
    end

    def self.search_with_status(andor, conditions, ex_andor, ex_conditions, status='ALL')
      hosts = self.search(andor, conditions, ex_andor, ex_conditions)
      unless status == 'ALL'
        stat_hosts = self.search( 'AND', [['status', status]], 'AND', [] );
        hosts = hosts & stat_hosts
      end
      return hosts
    end
  end

  module SmartSearch
    def self.kind(string)
      [
       [:service, "サービス", :service],
       [:serviceurl, "サービスURLをもつサービス", :service],
       [:dnsname, "DNS名", :host],
       [:hwid, "HWID", :host],
       [:ipaddress, "IPアドレス", :host],
       [:rackunit, "ラック位置", :host],
       [:tag, "タグ", :host],
       [:brickhwid, "機器情報 HWID", :brick],
       [:brickserial, "機器情報 シリアル", :brick]
      ]
    end

    def self.search(kind, keyword)
      case kind
      when :ipaddress
        Yabitz::Model::IPAddress.regex_match(:address => Regexp.compile(keyword)).map(&:hosts).flatten.compact
      when :service
        pattern = Regexp.compile(keyword, Regexp::IGNORECASE)
        Yabitz::Model::Service.regex_match(:name => pattern).flatten.compact
      when :serviceurl
        Yabitz::Model::ServiceURL.query(:url => keyword).map(&:services).flatten.compact
      when :rackunit
        plugins = Yabitz::Plugin.get(:racktype).select{|p| p.respond_to?(:search_extra_pattern)}
        patterns = [keyword] + plugins.map{|p| p.search_extra_pattern(keyword)}.flatten
        patterns.map{|p| Yabitz::Model::RackUnit.regex_match(:rackunit => Regexp.compile(p)).map(&:hosts)}.flatten.compact
      when :dnsname
        Yabitz::Model::DNSName.regex_match(:dnsname => Regexp.compile(keyword)).map(&:hosts).flatten.compact
      when :hwid
        Yabitz::Model::Host.query(:hwid => keyword)
      when :tag
        Yabitz::Model::TagChain.query(:tagchain => keyword).map(&:host).compact
      when :brickhwid
        Yabitz::Model::Brick.query(:hwid => keyword)
      when :brickserial
        Yabitz::Model::Brick.query(:serial => keyword)
      end
    end
  end

  module ServiceSearch
    SEARCH_KEY_LIST = ['name','content','charging','contact','mladdress','hypervisors','notes','urls']
    SEARCH_KEY_LABEL = {
      'name' => 'サービス名',
      'content' => 'コンテンツ名',
      'charging' => '課金設定',
      'contact' => '連絡先',
      'mladdress' => 'ML',
      'hypervisors' => 'ハイパーバイザ',
      'notes' => 'メモ',
      'urls' => 'サービスURL'
    }

    def self.search(conditions={})
      services = Yabitz::Model::Service.all.map{|srv| srv.oid }

      self::SEARCH_KEY_LIST.each{|key|
        conditions[key] ||= ''
      }

      if conditions['name'].length > 0
        pattern = Regexp.compile(conditions['name'], Regexp::IGNORECASE)
        result = Yabitz::Model::Service.regex_match(:name => pattern, :oidonly => true)
        services = services & result
      end

      if conditions['content'].length > 0
        pattern = Regexp.compile(conditions['content'], Regexp::IGNORECASE)
        result = Yabitz::Model::Content.regex_match(:name => pattern, :oidonly => true).map do |content_oid|
          Yabitz::Model::Service.query(:content => content_oid, :oidonly => true)
        end.flatten
        services = services & result
      end

      if conditions['charging'].length > 0
        result = Yabitz::Model::Content.query(:charging => conditions['charging'], :oidonly => true).map do |content_oid|
          Yabitz::Model::Service.query(:content => content_oid, :oidonly => true)
        end.flatten
        services = services & result
      end

      if conditions['contact'].length > 0
        pattern = Regexp.compile(conditions['contact'], Regexp::IGNORECASE)
        result = Yabitz::Model::Contact.regex_match(:label => pattern).map do |contact|
          Yabitz::Model::Service.query(:contact => contact, :oidonly => true)
        end.flatten
        services = services & result
      end

      if conditions['mladdress'].length > 0
        pattern = Regexp.compile(conditions['mladdress'], Regexp::IGNORECASE)
        result = Yabitz::Model::Service.regex_match(:mladdress => pattern, :oidonly => true)
        services = services & result
      end

      if conditions['hypervisors'].length > 0
        hypervisors = conditions['hypervisors'] == 'true' ? true : false
        result = Yabitz::Model::Service.query(:hypervisors => hypervisors, :oidonly => true)
        services = services & result
      end

      if conditions['notes'].length > 0
        pattern = Regexp.compile(conditions['notes'], Regexp::IGNORECASE)
        result = Yabitz::Model::Service.regex_match(:notes => pattern, :oidonly => true)
        services = services & result
      end

      if conditions['urls'].length > 0
        pattern = Regexp.compile(conditions['urls'], Regexp::IGNORECASE)
        result = Yabitz::Model::Service.all.select{|srv|
          srv.urls.select{|url| 
              url.to_s.match(pattern) 
          }.count > 0
        }.flatten.map{|srv| srv.oid }
        services = services & result
      end

      return Yabitz::Model::Service.get(services)
    end

    def self.smart_search ( keyword='' ) 
      unless keyword 
        return Yabitz::Model::Service.all
      end
      if keyword.length < 1
        return Yabitz::Model::Service.all
      end

      services = {}
      keywords = keyword.split(/(\s|　)/).select{|kw| ! kw.match(/(\s|　)/)}
      rtn = []

      for kw in keywords
        for key in self::SEARCH_KEY_LIST
          if key == 'hypervisors'
            next
          end
          srv_list = self.search( { key => kw } )
          services[kw] ||= []
          services[kw].push( srv_list )
        end
        services[kw] = services[kw].flatten.map{|srv| srv.oid}.uniq
      end

      for key in services.keys
        if rtn.size < 1
          rtn = services[key];
        else
          rtn = rtn & services[key]
        end
      end

      return Yabitz::Model::Service.get(rtn)
    end

    def self.searchkey_title ( key ) 
      return Yabitz::ServiceSearch::SEARCH_KEY_LABEL[key] ? Yabitz::ServiceSearch::SEARCH_KEY_LABEL[key] : nil
    end

  end
end
