class L2vpnServersController < ApplicationController
  layout nil

  before_filter :load_server
  before_filter :load_l2vpn_server, :except => [ :index, :new, :create ]
  before_filter :load_wisps, :except => [ :index, :show, :destroy ]
  before_filter :load_server_ip, :only => [ :new, :create, :edit ] 

  access_control :subject_method => :current_operator do
    default :deny

    allow :admin
  end

  def load_server_ip
    @server_ip = [] 
    @server.bridges.each{ |b| if b.addressing_mode == "static" 
                                    @server_ip << b.ip
                              end 
                        } 
    @server_ip << "all"
  end
  
  def load_server
    @server = Server.find(params[:server_id])
  end

  def load_l2vpn_server
    @l2vpn_server = @server.l2vpn_servers.find(params[:id])
  end

  def load_wisps
    @wisps = Wisp.all
  end


  def index
    @l2vpn_servers = @server.l2vpn_servers
  end
  
  def show
    
  end

  def new
    MiddleMan.worker(:l2vpn_server_worker).async_genDh
    MiddleMan.worker(:l2vpn_server_worker).async_genTls
    @l2vpn_server = L2vpnServer.new( :wisp => Wisp.first )
  end

  def edit
  end

  def create
    @l2vpn_server = @server.l2vpn_servers.build(params[:l2vpn_server])
    @l2vpn_server.tap = Tap.new()
    
    result = false
    @l2vpn_server.dh = MiddleMan.worker(:l2vpn_server_worker).getDh
    @l2vpn_server.tls_auth = MiddleMan.worker(:l2vpn_server_worker).getTls
    if !@l2vpn_server.dh.nil? and !@l2vpn_server.tls_auth.nil? and @l2vpn_server.save
      @l2vpn_server.generate_configuration
      @l2vpn_server.tap.save!
      respond_to do |format|
          flash[:notice] = t(:L2vpn_server_created)
          format.html { redirect_to(server_l2vpn_servers_url(@server)) }
          MiddleMan.worker(:l2vpn_server_worker).clean
      end
    else
      respond_to do |format|
        format.html { render :action => "new" }
      end
    end
  end

  def update
    if @l2vpn_server.update_attributes(params[:l2vpn_server])
      respond_to do |format|
          flash[:notice] = t(:L2vpn_server_updated)
          format.html { redirect_to(server_l2vpn_servers_url(@server)) }
      end
    else
      respond_to do |format|
        format.html { render :action => "edit" }
      end
    end
  end

  def destroy
    @l2vpn_server.destroy

    respond_to do |format|
      format.html { redirect_to(server_l2vpn_servers_url(@server)) }
    end
  end
end