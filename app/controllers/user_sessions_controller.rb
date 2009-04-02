class UserSessionsController < Spree::BaseController
  before_filter :require_no_user, :only => [:new, :create]
  before_filter :require_user, :only => :destroy
    
  def new
    @user_session = UserSession.new
  end

  def create
    @user_session = UserSession.new(params[:user_session])
    if @user_session.save
      flash[:notice] = t("logged_in_successfully")
      redirect_back_or_default products_path
    else
      flash.now[:error] = t("login_failed")
      render :action => :new
    end
  end

  def destroy
    current_user_session.destroy
    reset_session
    flash[:notice] = t("you_have_been_logged_out")
    redirect_back_or_default('/')
  end
end
