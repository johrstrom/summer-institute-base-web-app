# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions
  set :host_authorization, { permitted_hosts: ['ondemand.osc.edu'] }

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Summer Instititue Starter App'
  end

  get '/examples' do
    erb(:examples)
  end

  def project_dirs
    Dir.children(projects_root).select do |path|
      Pathname.new("#{projects_root}/#{path}").directory?
    end.sort_by(&:to_s)
  end

  def accounts
    Process.groups.map do |group_id|
      Etc.getgrgid(group_id).name
    end.select do |group|
      group.start_with?('P')
    end
  end

  def blend_files
    Dir.glob("#{__dir__}/blend_files/*.blend").map do |f|
      File.basename(f)
    end
  end

  post '/render/frames' do
    logger.info("rendering frames with #{params.inspect}")

    blend_file = "#{__dir__}/blend_files/#{params[:blend_file]}"
    walltime = format('%02d:00:00', params[:walltime])
    dir = params[:project_directory]

    args = ['-J', "blender-#{params[:blend_file]}", '--parsable', '-A', params[:account]]
    args.concat ['--export', "BLEND_FILE_PATH=#{blend_file},OUTPUT_DIR=#{dir},FRAME_RANGE=#{params[:frame_range]}"]
    args.concat ['-n', params[:num_cpus], '-N', '1', '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{dir}/%j.out"]

    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_frames.sh 2>&1`
    job_id = output.strip.split(';').first

    session[:flash] = { info: "submitted job #{job_id}" }
    redirect(url("/projects/#{dir.split('/').last}"))
  end

  get '/' do
    logger.info('requsting the index')
    @flash = session.delete(:flash) || { info: 'Welcome to Summer Institute!' }
    erb(:index)
  end

  get '/projects/:name' do
    if params[:name] == 'new'
      erb(:new_project)
    else
      @directory = Pathname.new("#{projects_root}/#{params[:name]}")
      @project_name = @directory.basename.to_s.gsub('_', ' ').capitalize
      @flash = session.delete(:flash)
      @images = Dir.glob("#{@directory}/*.png")

      if(@directory.directory? && @directory.readable?)
        erb(:show_project)
      else
        session[:flash] = { danger: "#{@directory} does not exist" }
        redirect(url('/'))
      end

    end
  end

  # helper function for the parent directory of all projects.
  def projects_root
    "#{__dir__}/projects"
  end

  post '/projects/new' do
    dir = params[:name].downcase.gsub(' ', '_')

    "#{projects_root}/#{dir}".tap { |d| FileUtils.mkdir_p(d) }

    session[:flash] = { info: "made new project '#{params[:name]}'" }
    redirect(url("/projects/#{dir}"))
  end

  post '/render/video' do
    logger.info("Trying to render video with: #{params.inspect}")

    output_dir = params[:project_directory]
    frames_per_second = params[:frames_per_second]
    walltime = format('%02d:00:00', params[:walltime])

    args = ['-J', 'blender-video', '--parsable', '-A', params[:account]]
    args.concat ['--export', "FRAMES_PER_SEC=#{frames_per_second},OUTPUT_DIR=#{output_dir}"]
    args.concat ['-n', params[:num_cpus], '-N', '1', '-t', walltime, '-M', 'pitzer']
    args.concat ['--output', "#{output_dir}/video-render-%j.out"]
    output = `/bin/sbatch #{args.join(' ')}  #{__dir__}/scripts/render_video.sh 2>&1`

    
    job_id = output.strip.split(';').first

    session[:flash] = { info: "Submitted job #{job_id}"}
    redirect(url("/projects/#{output_dir.split('/').last}"))
  end
end