class PapersController < ApplicationController
  include PapersHelper

  def show
    @paper = Paper.find_by_uid(params[:id])

    if @paper.nil?
      # Might be a versioned link
      @paper = Paper.find_by_uid!(params[:id].split(/v\d/)[0])
      redirect_to paper_path(@paper)
    end

    @scited = current_user && current_user.scited_papers.where(id: @paper.id).exists?

    # Less naive statistical comment sorting as per
    # http://www.evanmiller.org/how-not-to-sort-by-average-rating.html
    @toplevel_comments = Comment.find_by_sql([
      "SELECT *, COALESCE(((cached_votes_up + 1.9208) / NULLIF(cached_votes_up + cached_votes_down, 0) - 1.96 * SQRT((cached_votes_up * cached_votes_down) / NULLIF(cached_votes_up + cached_votes_down, 0) + 0.9604) / NULLIF(cached_votes_up + cached_votes_down, 0)) / (1 + 3.8416 / NULLIF(cached_votes_up + cached_votes_down, 0)), 0) AS ci_lower_bound FROM comments WHERE paper_uid = ? AND ancestor_id IS NULL AND (hidden = FALSE OR user_id = ?) ORDER BY ci_lower_bound DESC, created_at ASC;",
      @paper.uid,
      current_user ? current_user.id : nil
    ])

    @comment_tree = {}
    @paper.comments.where("ancestor_id IS NOT NULL").order("created_at ASC").each do |c|
      @comment_tree[c.ancestor_id] ||= []
      @comment_tree[c.ancestor_id] << c
    end

    @comments = []
    @toplevel_comments.each do |c|
      @comments << c
      @comments += @comment_tree[c.id]||[]
    end

    @comments = @comments.reject do |c| 
      c.deleted && (@comment_tree[c.id].nil? || @comment_tree[c.id].all? { |c2| c2.deleted })
    end
  end

  def __quote(val)
    val.include?(' ') ? "(#{val})" : val
  end

  def search
    basic = params[:q]
    advanced = params[:advanced]
    page = params[:page] ? params[:page].to_i : 1

    @search = Search::Paper::Query.new(basic, advanced)

    per_page = 70

    if !@search.query.empty?
      paper_uids = @search.run(from: (page-1)*per_page, size: per_page).documents.map(&:_id)

      @papers = Paper.includes(:authors, :feeds)
                     .where(uid: paper_uids)
                     .index_by(&:uid)
                     .slice(*paper_uids)
                     .values

      @pagination = WillPaginate::Collection.new(page, per_page, @search.results.raw.hits.total)

      # Determine which folder we should have selected
      @folder_uid = @search.feed && (@search.feed.parent_uid || @search.feed.uid)

      @scited_ids = current_user.scited_papers.pluck(:id) if current_user
    end

    render :search
  end

  # Show the users who scited this paper
  def scites
    @paper = Paper.find_by_uid!(params[:id])
  end

  def next
    date = parse_date params
    feed = parse_feed params

    if feed.nil? && signed_in? && current_user.has_subscriptions?
       date ||= current_user.feed_last_paper_date

      papers = current_user.feed
    else
      feed ||= Feed.default
      date ||= feed.last_paper_date

      papers = feed.cross_listed_papers
    end

    ndate = next_date(papers, date)

    if ndate.nil?
      flash[:error] = "No future papers found!"
      ndate = date
    end

    redirect_to papers_path(params.merge(date: ndate, action: nil))
  end

  def prev
    date = parse_date params
    feed = parse_feed params

    if feed.nil? && signed_in? && current_user.has_subscriptions?
      date ||= current_user.feed_last_paper_date
      papers = current_user.feed
    else
      feed ||= Feed.default
      date ||= feed.last_paper_date

      papers = feed.cross_listed_papers
    end

    pdate = prev_date(papers, date)

    if pdate.nil?
      flash[:error] = "No past papers found!"
      pdate = date
    end

    redirect_to papers_path(params.merge(date: pdate, action: nil))
  end
end
