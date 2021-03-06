#!/usr/bin/env ruby

# Script to import tumblr posts into local markdown posts ready to be consumed by Jekyll.
# Inspired by New Bamboo's post http://blog.new-bamboo.co.uk/2009/2/20/migrating-from-mephisto-to-jekyll
# Supports post types: regular, quote, link, photo, video and audio
# Saves local copies of images

require 'rubygems'
require 'open-uri'
require 'nokogiri'
require 'net/http'
require 'mime/types'
require 'fileutils'
require 'pathname'
require 'date'

# Configuration
TUMBLR_DOMAIN =   "http://eatsleeprepeat.net"
WRITE_DIRECTORY = "_posts"
IMAGE_DIRECTORY = "../images"
LAYOUT = "post"

# follow 3xx redirection
def fetch(uri_str, limit = 10)
  raise ArgumentError, 'HTTP redirect too deep' if limit == 0

  response = Net::HTTP.get_response(URI.parse(uri_str))
  case response
  when Net::HTTPSuccess     then response
  when Net::HTTPRedirection then fetch(response['location'], limit - 1)
  else
    response.error!
  end
end

# save a local copy of a tumblr-hosted image and return the relative uri
def fetch_img(uri_str) 

  uri = URI.parse(uri_str)

  resp = fetch(uri_str)
  mime_type = MIME::Types[resp["content-type"]].first

  # build our local image path
  path = "#{uri.host}#{uri.path}"

  # rewrite extension
  extension = mime_type.extensions.first
  extension = extension == "jpeg" ? "jpg" : extension
  path = "#{path.chomp(File.extname(path))}.#{extension}"

  print "Image: #{uri_str} --> #{path}\n"

  local_path = "#{IMAGE_DIRECTORY}/#{path}"
  FileUtils.mkdir_p Pathname.new(local_path).dirname
  open(local_path, "wb") { |file| file.write(resp.body) }

  return "/images/#{path}"
end

# Tumblr api only returns 50 posts per call
post_offset = 0
posts_returned = -1
while posts_returned != 0

  path = TUMBLR_DOMAIN + "/api/read?num=50&filter=none&start=#{post_offset}"

  # Connect to Tumblr and read the API source
  open(path) do |xml|
    doc = Nokogiri::XML.parse(xml)
    posts = doc.css("post")
    posts_returned = posts.count
    post_offset += posts.count
    posts.each do |post_tag|

      # Gather data about each post 
      date = Date.parse(post_tag.attributes["date"].content)
      id = post_tag.css("@id").first.content
      slug_tag = post_tag.css("slug").first
      slug = slug_tag.nil? ? nil : slug_tag.content
      type = post_tag.attributes["type"].content
      tags = post_tag.css("tag").map{|t| t.content }
      title = nil
      body = nil

      if type == "regular"    
        title_tag = post_tag.css("regular-title").first
        title = title_tag.nil? ? nil : title_tag.content
        body = post_tag.css("regular-body").first.content
      elsif type == "quote"    
        text = post_tag.css("quote-text").first.content
        source = post_tag.css("quote-source").first.content
        body = "> #{text}" + "\n\n" + source
      elsif type == "link"
        text_tag = post_tag.css("link-text").first
        text = text_tag.nil? ? nil : text_tag.content
        link = post_tag.css("link-url").first.content
        body = ""
        desc_tag = post_tag.css("link-description").first
        if desc_tag != nil
          body << "#{desc_tag.content}"
        end
      elsif type == "photo"
        body = ""  

        photoset_tag = post_tag.css("photoset").first
        if photoset_tag.nil?
          body += "<img src=\"#{fetch_img(post_tag.css("photo-url").first.content)}\" />"
        else
          post_tag.css("photo").each do |photo_tag|
            body += "<img src=\"#{fetch_img(photo_tag.css("photo-url").first.content)}\" />"
          end
        end
        text = post_tag.css("photo-caption").first.content
        body += "\n\n#{text}" 
      elsif type == "video"
        caption_tag = post_tag.css("video-caption").first 
        if caption_tag != nil
          text = caption_tag.content
        end
        body = post_tag.css("video-source").first.content
      elsif type == "audio"
        caption_tag = post_tag.css("audio-caption").first 
        text = caption_tag.nil? ? nil : caption_tag.content
        body = post_tag.css("audio-player").first.content
      else
        print "ERROR: Post type not supported\n"
        next
      end

      if !title && !text
        print "ERROR: Post title and text are nil: #{id}\n"
        next
      end

      # title defaults
      title ||= text
      title = title.gsub(/<.*?>/,'') # strip html
      #title = title.length > 60 ? (title[0,60] + "…") : title # limit length

      # create the slug if necessary and build a _post filename
      if slug.nil? 
        slug = "#{title.gsub(/(\s|[^a-zA-Z0-9])/,"-").gsub(/-+/,'-').gsub(/-$/,'').downcase}"
      end
      filename = "#{date.strftime("%Y-%m-%d")}-#{slug}.html"

      # if there's no post, we give up.
      if !body
        next
      end

      tagcode = ""
      if tags.size > 0
        tagcode = "categories:\n"
        for t in tags
          tagcode << "  - #{t}\n"
        end
      end

      jekyll_post = <<-EOPOST
---
layout: #{LAYOUT}
title: #{title}
date: #{date.strftime("%Y-%m-%d")}
comments: "false"
categories: Photography
---

#{body}
EOPOST

      # Write files
      puts "#{ filename }"
      #puts jekyll_post
      #puts ""

      file = File.new("#{WRITE_DIRECTORY}/#{filename}", "w+")
      file.write(jekyll_post)
      file.close

    end
  end
end
