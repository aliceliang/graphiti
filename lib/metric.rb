class Metric
  include Redised

  def self.all(refresh = false)
    redis_metrics = redis.get("metrics")
    @metrics = redis_metrics.split("\n") if redis_metrics
    return @metrics if @metrics && !@metrics.empty? && !refresh
    @metrics = []
    get_metrics_list
    redis.set "metrics", @metrics.join("\n")
    @metrics
  end

  def self.find(match, max = 100)
    match = match.to_s.strip
    matches = []
    all.each do |m|
      if m =~ /#{match.strip}/i
        matches << m
      end
      break if matches.length > max
    end
    matches
  end

  def self.into_magic
    magic = Hash.new([])
    all.each do |e|
      e = e.split(".")
      env = e[0]
      service = e[2].gsub("-server", "")
      magic[env] = magic[env].concat([service]) if e[2]["-server"]
    end
    magic.each do |k, v|
      v.uniq!
      redis.hset "magic", k, v.join("\n")
    end
  end

  def self.get_envs
    redis.hkeys "magic"
  end

  def self.get_services(env)
    services = redis.hget "magic", env
    services.split("\n")
  end

  private
  def self.get_metrics_list(prefix = Graphiti.settings.metric_prefix)
    url = "#{Graphiti.settings.graphite_base_url}/metrics/index.json"
    puts "Getting #{url}"
    response = Typhoeus::Request.get(url)
    if response.success?
      json = Yajl::Parser.parse(response.body)
      json.map! { |e| e = e[1..-1] }
      if prefix.nil?
        @metrics = json
      elsif prefix.kind_of?(Array)
        @metrics = json.grep(/^[#{prefix.map! { |k| Regexp.escape k }.join("|")}]/)
      else
        @metrics = json.grep(/^#{Regexp.escape prefix}/)
      end
    else
      puts "Error fetching #{url}. #{response.inspect}"
    end
    @metrics.sort
  end

end
