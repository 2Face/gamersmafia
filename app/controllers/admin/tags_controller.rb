class Admin::TagsController < AdministrationController
  before_filter do |c|
    raise AccessDenied unless c.user && (c.user.has_admin_permission?(:capo) || c.user.is_hq?)
  end

  def index

  end

  def destroy
    uct = UsersContentsTag.find(params[:id])
    if uct.term.contents_terms.count > UsersContentsTag::MAX_TAGS_REFERENCES_BEFORE_DELETE
      raise "Tried to delete tag with #{uct.term.contents_terms.count} references!"
    else
      uct.destroy
    end
    @js_response = "$j('#tag#{uct.id}').fadeOut('normal');"
    render :partial => '/shared/silent_ajax_feedback',
           :locals => { :js_response => @js_response }
  end
end
