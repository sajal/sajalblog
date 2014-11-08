# A ruby class to fetch suggested keywords using Yahoo's term Extraction API
 require 'rubygems'
require 'xmlsimple'
require 'net/http'

class Tagger
  def content
    @content
  end
  def content=(content)
    @content = content
  end
    def appid
    @appid
  end
  def appid=(appid)
    @appid = appid
  end
  def initialize
    
  end
  def fetch
          url = URI.parse('http://search.yahooapis.com/ContentAnalysisService/V1/termExtraction')
      post_args = {
            'appid' => appid,
            'context' => content,
            'output' => "xml"
      }
      resp1, xml_data = Net::HTTP.post_form(url, post_args)
      keywords = ""
      data = XmlSimple.xml_in(xml_data)
      data['Result'].each do |item|
      keywords = keywords + item + ", "
      end
      return keywords
  end
end

