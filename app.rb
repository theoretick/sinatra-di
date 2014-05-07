require 'rubygems'
require 'bundler'
Bundler.require
require 'sinatra/reloader'

require './lib/discuss_it'

module DiscussIt
  class App < Sinatra::Base

  configure :development do
    register Sinatra::Reloader
  end

    get '/' do
      haml :index
    end

    get '/submit' do
      # remove params from base url
      @query_url = params[:url].split("?").first

      haml :submit, locals: {query_url:  @query_url}
    end

    get '/about' do
      haml :about
    end

    get '/api' do
      haml :developers
    end
    get '/api/get_discussions?:url?' do
      content_type :json

      @query_url = params[:url]
      results = {}

      # ALWAYS remove trailing slash before get_response calls
      @query_url.chop! if @query_url.end_with?('/')

      # caching discussit API calls
      # TODO: breakup this caching for individual calls.
      discuss_it = DiscussIt::DiscussItApi.new(@query_url, source: 'all')

      top_raw ||= discuss_it.find_top
      all_raw ||= discuss_it.find_all.all
      @errors = discuss_it.errors.collect(&:message)

      @top_results, filtered_top_results = DiscussIt::Filter.filter_threads(top_raw)
      @all_results, filtered_all_results = DiscussIt::Filter.filter_threads(all_raw)

      @filtered_results = (filtered_all_results + filtered_top_results).uniq

      results = {
           total_hits: total_hits_count,
          top_results: {
                   hits: top_hits_count,
                results: @top_results
            },
          all_results: {
                   hits: all_hits_count,
                results: @all_results
          },
          filtered_results: {
                   hits: filtered_hits_count,
                results: @filtered_results
          },
          errors: @errors
        }

      results.to_json
    end

    private

    # returns the total number of hits for top + all results
    def total_hits_count
      return top_hits_count + all_hits_count
    end

    # returns the total number of hits for top results
    def top_hits_count
      return @top_results.length || 0
    end

    # returns the total number of hits for all results
    def all_hits_count
      return @all_results.length || 0
    end

    # returns the total number of hits for filtered results
    def filtered_hits_count
      return @filtered_results.length || 0
    end
  end
end
