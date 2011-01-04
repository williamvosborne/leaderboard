require 'redis'

class Leaderboard
  VERSION = '1.0.0'.freeze
  DEFAULT_PAGE_SIZE = 25
  
  attr_reader :host
  attr_reader :port
  attr_reader :leaderboard_name
  attr_reader :page_size
  
  def initialize(leaderboard_name, host = 'localhost', port = 6379, page_size = DEFAULT_PAGE_SIZE)
    @leaderboard_name = leaderboard_name
    @host = host
    @port = port
    
    if page_size < 1
      page_size = DEFAULT_PAGE_SIZE
    end
    
    @page_size = page_size
    
    @redis_connection = Redis.new(:host => @host, :port => @port)
  end
      
  def add_member(member, score)
    @redis_connection.zadd(@leaderboard_name, score, member)
  end
  
  def remove_member(member)
    @redis_connection.zrem(@leaderboard_name, member)
  end
  
  def total_members
    @redis_connection.zcard(@leaderboard_name)
  end
  
  def total_pages
    (total_members / @page_size.to_f).ceil
  end
  
  def total_members_in_score_range(min_score, max_score)
    @redis_connection.zcount(@leaderboard_name, min_score, max_score)
  end
  
  def change_score_for(member, delta)
    @redis_connection.zincrby(@leaderboard_name, delta, member)
  end
  
  def rank_for(member, use_zero_index_for_rank = false)    
    if use_zero_index_for_rank
      return @redis_connection.zrevrank(@leaderboard_name, member)
    else
      return @redis_connection.zrevrank(@leaderboard_name, member) + 1 rescue nil
    end
  end
  
  def score_for(member)
    @redis_connection.zscore(@leaderboard_name, member).to_f
  end

  def leaders(current_page, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    if current_page < 1
      current_page = 1
    end
    
    if current_page > total_pages
      current_page = total_pages
    end
    
    index_for_redis = current_page - 1

    starting_offset = (index_for_redis * @page_size)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + @page_size) - 1
    
    raw_leader_data = @redis_connection.zrevrange(@leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
    if raw_leader_data
      massage_leader_data(raw_leader_data, with_rank, use_zero_index_for_rank)
    else
      return nil
    end
  end
  
  def around_me(member, with_scores = true, with_rank = true, use_zero_index_for_rank = false)
    reverse_rank_for_member = @redis_connection.zrevrank(@leaderboard_name, member)
    
    starting_offset = reverse_rank_for_member - (@page_size / 2)
    if starting_offset < 0
      starting_offset = 0
    end
    
    ending_offset = (starting_offset + @page_size) - 1
    
    raw_leader_data = @redis_connection.zrevrange(@leaderboard_name, starting_offset, ending_offset, :with_scores => with_scores)
    if raw_leader_data
      massage_leader_data(raw_leader_data, with_rank, use_zero_index_for_rank)
    else
      return nil
    end
  end
  
  def ranked_in_list(members, with_scores = true, use_zero_index_for_rank = false)
    ranks_for_members = []
    
    members.each do |member|
      data = {}
      data[:member] = member
      data[:rank] = rank_for(member, use_zero_index_for_rank)
      data[:score] = score_for(member) if with_scores
      
      ranks_for_members << data
    end
    
    ranks_for_members
  end
  
  private 
  
  def massage_leader_data(leaders, with_rank, use_zero_index_for_rank)
    member_attribute = true    
    leader_data = []
    
    data = {}        
    leaders.each do |leader_data_item|
      if member_attribute
        data[:member] = leader_data_item
      else
        data[:score] = leader_data_item
        data[:rank] = rank_for(data[:member], use_zero_index_for_rank) if with_rank
        leader_data << data
        data = {}     
      end
            
      member_attribute = !member_attribute
    end
    
    leader_data
  end
end