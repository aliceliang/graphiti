require 'uri'
require 'fileutils'

class Magic
  def self.magic=(val)
    @magic = val
  end

  def self.read_magic
    Yajl::Parser.parse(File.read(@magic))
  end

  def self.base_url=(val)
    @base_url = val
  end

  def self.base_url
    @base_url + "/render/?"
  end

  def self.build_url(graph_json)
    url = base_url
    graph_json['options'].each{|key, value| url << "#{key}=#{URI.escape(value)}&"}
    graph_json['targets'].map{|e| url << "target=#{e}&"}
    url << "_timestamp_=#{Time.now.to_f*1000}&#.png"
  end

  def self.config_json(env, service)
    jsons = read_magic
    jsons.map do |e|
      e['targets'].map! {|t| t[0].gsub('{service}', service).gsub('{env}', env)}
    end
    jsons
  end

  def self.make_graphs(env, service)
    json = config_json(env, service)
    json.map do |e|
      Graph.save_magic(Yajl::Encoder.encode(e),
                       e['options']['title'],
                       build_url(e))
    end
  end

  def self.make_dashboard(env=nil, service)
    env ||= "*"
    dash = {title: "#{service} (#{env})", slug: "#{env} #{service}"}
    dash_json = Dashboard.save(dash)
    graph_uuids = make_graphs(env, service)
    graph_uuids.map { |u| Dashboard.add_graph(dash_json[:slug], u)}
    dash_json
  end

end
