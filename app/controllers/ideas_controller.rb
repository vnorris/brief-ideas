class IdeasController < ApplicationController
  before_filter :require_user, :only => [ :new, :create, :hide, :accept_invite, :submit ]
  respond_to :json, :html, :atom

  def index
    @ideas = Idea.by_date.visible.for_user(current_user).limit(10)
    @recent = true

    respond_to do |format|
      format.atom
      format.json { render :json => @ideas }
      format.html
    end
  end

  def trending
    @ideas = Idea.trending.visible.by_date.for_user(current_user).paginate(:page => params[:page], :per_page => 10)
    @trending = true

    respond_to do |format|
      format.atom { render :template => 'ideas/index' }
      format.json { render :json => @ideas }
      format.html { render :template => 'ideas/index' }
    end
  end

  def all
    @ideas = Idea.by_date.visible.for_user(current_user).paginate(:page => params[:page], :per_page => 10)
    @all = true

    respond_to do |format|
      format.atom { render :template => 'ideas/index' }
      format.json { render :json => @ideas }
      format.html { render :template => 'ideas/index' }
    end
  end

  def new
    @tags = Idea.all_tags
    @idea = Idea.new
  end

  def create
    @idea = Idea.new(idea_params)
    @idea.tags = idea_params['tags'].split(',').collect(&:strip).collect(&:downcase)
    @idea.authors << current_user

    if @idea.save
      redirect_to idea_path(@idea), :notice => "Idea created"
    else
      render :action => "new"
    end
  end

  def add_comment
    @idea = Idea.find_by_sha(params[:id])
    @comment = @idea.comments.build(comment_params)
    @comment.user = current_user

    if @comment.save
      respond_to do |format|
        format.js
        format.html { redirect_to(:back, :notice => "Comment added")}
      end
    else
      redirect_to(:back)
    end
  end

  def preview
    filter = HTML::Pipeline::MarkdownFilter.new(params[:idea])
    render :text => filter.call
  end

  def hide
    @idea = Idea.find_by_sha(params[:id])
    current_user.dismiss!(@idea)
    redirect_to(:back, :notice => "Idea hidden")
  end

  def similar
    @ideas = Idea.similar_ideas(params[:idea])

    respond_to do |format|
      format.html { render :layout => false }
    end
  end

  def tags
    render :json => Idea.all_tags.to_json
  end

  def show
    @idea = Idea.find_by_sha(params[:id])

    unless @idea
      redirect_to ideas_path, :notice => "Idea not found" and return
    end

    impressionist(@idea)

    respond_to do |format|
      format.html
      format.json { render :json => @idea }
    end
  end

  def about

  end

  def submit
    @idea = Idea.find_by_sha(params[:id])

    # Only let the submitting author submit an idea
    unless @idea.submitting_author == current_user
      redirect_to idea_path(@idea), :notice => "Only the submitting author can submit an idea" and return
    end

    if @idea.pending?
      @idea.submit!
      redirect_to idea_path(@idea), :notice => "Idea submitted"
    else
      redirect_to idea_path(@idea), :notice => "Your idea could not be submitted"
    end
  end

  def accept_invite
    @idea = Idea.find_by_sha(params[:id])

    if current_user.email.blank?
      redirect_to idea_path(@idea), :notice => "You must add an email to your account before becoming an authorship" and return
    # Can't become and author of something that's already published.
    elsif @idea.published?
      redirect_to idea_path(@idea), :notice => "This idea is already published" and return
    # Or rejected
    elsif @idea.rejected?
      redirect_to ideas_path, :notice => "This idea is was rejected" and return
    # Or if you've already accepted authorship
    elsif @idea.authors.include?(current_user)
      redirect_to idea_path(@idea), :notice => "You're already an author of this idea" and return
    else
      @idea.add_author!(current_user)
    end

    redirect_to idea_path(@idea), :notice => "Authorship accepted!"
  end

  def boom
    raise "Hell"
  end

  def lookup_title
    @results = Idea.fuzzy_search_by_title(params[:query]).limit(3)
    respond_with @results
  end

private

  def idea_params
    params.require(:idea).permit(:title, :body, :subject, :tags, :citation_ids)
  end

  def comment_params
    params.require(:comment).permit(:comment)
  end
end
