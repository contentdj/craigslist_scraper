require 'nokogiri'
require 'open-uri'
require 'cgi'
require_relative 'cities'

class CraigsList
  include Cities
  
  VALID_FIELDS = [:query, :srchType, :s]
  
  ERRORS = [OpenURI::HTTPError]
  
  def search(options ={})
    if options[:title_only]
      options.merge!(srchType: "T")
      options.delete(:title_only)
    end
    uri = "http://#{options[:city]}.craigslist.org/search/sss?#{to_query(options)}"

    begin
      doc = Nokogiri::HTML(open(uri))

      parse_item(options[:city], doc)
    rescue *ERRORS => e
      [{error: "error opening city: #{options[:city]}"} ]
    end
  end

  def section(options ={})
    if options[:title_only]
      options.merge!(srchType: "T")
      options.delete(:title_only)
    end
    uri = "http://#{options[:city]}.craigslist.org/search/#{options[:section]}?#{to_query(options)}"

    begin
      doc = Nokogiri::HTML(open(uri))
      
      parse_item(options[:city], doc)
    rescue *ERRORS => e
      [{error: "error opening city: #{options[:city]}"} ]
    end
  end

  def cities
    Cities::CITIES
  end
  
  def method_missing(method,*args)
    super unless Cities::CITIES.include? city ||= extract_city(method)
    
    params = { query: args.first , city: city}
    params.merge!(title_only: true) if /titles/ =~ method
      
    search(params)
  end

  def search_all_cities_for(query)
    Cities::CITIES.flat_map do |city|
      search(city: city , query: query)
    end
  end
  
  Array.class_eval do
    def average_price
      reject! { |item| item[:price] == nil }
      return 0 if empty?

      price_array.reduce(:+) / size 
    end

    def median_price
      reject! { |item| item[:price] == nil }

      return 0 if empty?
      return first[:price].to_i if size == 1

      if size.odd?
        price_array.sort[middle]
      else
        price_array.sort[middle - 1.. middle].reduce(:+) / 2
      end
    end

    private

    def middle
      size / 2
    end

    def price_array
      flat_map { |item| [item[:price]] }.map { |price| price.to_i }
    end
  end
  
private
  
  def parse_item(city, doc)
    doc.css('p.row').flat_map do |link|
      [
       data_id: link["data-pid"],
       description: link.css("span.pl a").text,
       posted_at: link.at('time')["datetime"],
       url: "http://#{city}.craigslist.org#{link.css("a")[0]["href"]}",
       price: !link.at("span.price").nil? ? extract_price(link.at("span.price").text) : 0
      ]
    end
  end

  def extract_city(method_name)
    
    if /titles/ =~ method_name
      method_name.to_s.gsub("search_titles_in_","").gsub("_for","")
    else
      method_name.to_s.gsub("search_","").gsub("_for","")
    end
  end
  
  def extract_price(dollar_string)
    dollar_string[1..-1]
  end
  
  def to_query(hsh)
    hsh.select { |k,v| CraigsList::VALID_FIELDS.include? k }.map {|k, v| "#{k}=#{CGI::escape v}" }.join("&")
  end

end
