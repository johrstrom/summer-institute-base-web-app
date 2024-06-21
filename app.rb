# frozen_string_literal: true

require 'sinatra/base'
require 'logger'

# App is the main application where all your logic & routing will go
class App < Sinatra::Base
  set :erb, escape_html: true
  enable :sessions

  attr_reader :logger

  def initialize
    super
    @logger = Logger.new('log/app.log')
  end

  def title
    'Jeffs Blender App'
  end
  
  def accounts
      Process.groups.map do |gid|
          Etc.getgrgid(gid).name
      end.select do |group|
          group.start_with?('P')
      end
  end
  
  def blend_files
      Dir.glob("#{__dir__}/blend_files/*.blend")
  end
  
  def images(ghghg)
      Dir.glob("#{ghghg}/*.png")
  end
  
  post '/render/frames' do
      
    # "account"=>"PZS0714", 
    # "blend_file"=>"/users/PZS0714/johrstrom/ondemand/dev/blender/blend_files/red_autumn.blend", 
    # "num_cpus"=>"4", 
    # "frame_range"=>"1..20", 
    # "walltime"=>"1",    --->  01:00:00
    # "project_directory"=>"/users/PZS0714/johrstrom/ondemand/dev/blender/projects/star_warz"
    
    walltime = format('%02d:00:00', params[:walltime])

    exports = "BLEND_FILE_PATH=#{params[:blend_file]}"
    exports = "#{exports},OUTPUT_DIR=#{params[:project_directory]}"
    exports = "#{exports},FRAME_RANGE=#{params[:frame_range]}"
    
    args = ['-A', params[:account], '-n', params[:num_cpus]]
    args.concat(['-t', walltime, '-M', 'pitzer', '--parsable'])
    args.concat(['--export', exports])
    
    script = "#{__dir__}/scripts/render_frames.sh"
    
    output = `/bin/sbatch #{args.join(' ')} #{script} 2>&1`
    session[:flash] = { info: "Submitted job with id: '#{output.split(';').first}'" }
    
    redirect(url("/projects/#{File.basename(params[:project_directory])}"))
  end
  
  post '/render/video' do
    
    walltime = format('%02d:00:00', params[:walltime])
    script = "#{__dir__}/scripts/render_video.sh"
    exports = "FRAMES_PER_SEC=#{params[:frames_per_second]}"
    exports = "#{exports},OUTPUT_DIR=#{params[:project_directory]}"
    
    args = ['-A', params[:account], '-n', params[:num_cpus]]
    args.concat(['-M', 'pitzer', '--parsable'])
    args.concat(['-t', walltime, '--export', exports])
    
    output = `/bin/sbatch #{args.join(' ')} #{script} 2>&1`
    
    session[:flash] = { info: "Submited job with output: '#{output}'" }
    redirect(url("/projects/#{File.basename(params[:project_directory])}"))
  end


  get '/examples' do
    erb(:examples)
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
        @flash = session.delete(:flash)
        @images = images(@directory)
        
        if(@directory.exist? && @directory.directory?)
            erb(:show_project)
        else
            session[:flash] = { danger: "There is no project named '#{params[:name]}'." }

            redirect(url("/")) 
        end
    end
  end
  
  def sanitize_project_name(name)
      # 'Star Wars'  ->   star_wars
      name.downcase.gsub(' ', '_')
  end
  
  # /users/PZS0714/johrstrom/ondemand/dev/blender   ---> __dir__
  #                                              /projects
  def projects_root
      "#{__dir__}/projects"
  end
  
  def projects
      Dir.children(projects_root).select do |path|
          Pathname.new("#{projects_root}/#{path}").directory?
      end.sort_by(&:to_s)
  end
  
  post '/projects/new' do
    directory_name = sanitize_project_name(params[:name])
    
    FileUtils.mkdir_p("#{projects_root}/#{directory_name}")
    session[:flash] = { info: "Created project '#{params[:name]}'." }

    redirect(url("/"))
  end
end
