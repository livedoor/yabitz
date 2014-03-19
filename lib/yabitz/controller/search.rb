# -*- coding: utf-8 -*-

require 'sinatra/base'

require 'haml'

class Yabitz::Application < Sinatra::Base
  ### detailed search ###
  get %r!/ybz/search(\.json|\.csv)?! do |ctype|
    authorized?

    @page_title = "ホスト検索"
    @hosts = nil
    andor = 'AND'
    conditions = []
    ex_andor = 'AND'
    ex_conditions = []
    cond_status = request.params['status'] ? request.params['status'] : 'ALL'
    if request.params['andor']
      andor = (request.params['andor'] == 'OR' ? 'OR' : 'AND')
      request.params.keys.map{|k| k =~ /\Acond(\d+)\Z/; $1 ? $1.to_i : nil}.compact.sort.each do |i|
        next if request.params["value#{i}"].nil? or request.params["value#{i}"].empty?
        search_value = request.params["value#{i}"].strip
        conditions.push([request.params["field#{i}"], search_value])
      end
      ex_andor = (request.params['ex_andor'] == 'OR' ? 'OR' : 'AND')
      request.params.keys.map{|k| k =~ /\Aex_cond(\d+)\Z/; $1 ? $1.to_i : nil}.compact.sort.each do |i|
        next if request.params["ex_value#{i}"].nil? or request.params["ex_value#{i}"].empty?
        ex_search_value = request.params["ex_value#{i}"].strip
        ex_conditions.push([request.params["ex_field#{i}"], ex_search_value])
      end
      @hosts = Yabitz::DetailSearch.search_with_status(andor, conditions, ex_andor, ex_conditions, cond_status)
    end

    Stratum.preload(@hosts, Yabitz::Model::Host) if @hosts
    case ctype
    when '.json'
      response['Content-Type'] = 'application/json'
      @hosts.to_json
    when '.csv'
      response['Content-Type'] = 'text/csv'
      Yabitz::Model::Host.build_raw_csv(Yabitz::Model::Host::CSVFIELDS_LL, @hosts)
    else
      counter = 0
      keyvalues = []
      conditions.each{|f,v| keyvalues.push("cond#{counter}=#{counter}&field#{counter}=#{f}&value#{counter}=#{v}"); counter += 1}
      counter = 0
      ex_conditions.each{|f,v| keyvalues.push("ex_cond#{counter}=#{counter}&ex_field#{counter}=#{f}&ex_value#{counter}=#{v}"); counter += 1}
      csv_url = '/ybz/search.csv?andor=' + andor + '&ex_andor=' + ex_andor + '&' + keyvalues.join('&')
      @copypastable = true
      haml :detailsearch, :locals => {
        :andor => andor, :conditions => conditions,
        :ex_andor => ex_andor, :ex_conditions => ex_conditions,
        :csv_url => csv_url, :cond_status => cond_status
      }
    end
  end
end
