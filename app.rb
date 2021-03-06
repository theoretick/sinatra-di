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
      @query_url = strip_params? ? params[:url].split("?").first : params[:url]
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
      source = set_source

      # ALWAYS remove trailing slash before get_response calls
      @query_url.chop! if has_trailing_slash?

      discuss_it = DiscussIt::DiscussItApi.cached_request(@query_url, source: source)

      top_raw ||= discuss_it.find_top
      all_raw ||= discuss_it.find_all.all
      @errors = discuss_it.errors.collect(&:message)

      @top_results, filtered_top_results = DiscussIt::Filter.filter_threads(top_raw)
      @all_results, filtered_all_results = DiscussIt::Filter.filter_threads(all_raw)
      @other_results = @all_results - @top_results
      @filtered_results = (filtered_all_results + filtered_top_results).uniq

      result_response.to_json
    end

    private

    # remove params from base url if requested (default: true)
    def strip_params?
      params[:strip_params] == 'true'
    end

    def has_trailing_slash?
      @query_url.end_with?('/')
    end

    def set_source
      params[:source] || ['all']
    end

    # build response hash one node at a time
    def result_response
      [
        total_hits_node,
        results_node(:top_results, @top_results),
        results_node(:other_results, @other_results),
        results_node(:filtered_results, @filtered_results),
        errors_node
      ].inject(&:merge)
    end

    # returns the total number of hits for top + all results
    def total_hits_node
      {total_hits: total_hits_count}
    end

    def results_node(key, results)
      {
        key => {
          hits: hit_count_of(results),
          results: results
        }
      }
    end

    def errors_node
      {errors: @errors}
    end

    def total_hits_count
      hit_count_of(@top_results) + hit_count_of(@other_results)
    end

    def hit_count_of(results)
      results.length || 0
    end

  end
end
