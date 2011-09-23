module QueryCapture
  def self.included(base)
    base.class_eval do
      extend ClassMethods
      cattr_accessor :queries
      self.queries = []
    end
  end

  def select_all(*args)
    sql = args.first
    self.class.queries << sql
    super
  end

  module ClassMethods
    def clear_captured_queries
      self.queries = []
    end

    def total_queries
      self.queries.size
    end
  end
end

class ActiveRecord::ConnectionAdapters::AbstractAdapter
  include QueryCapture
end

class ActiveSupport::TestCase
  setup :reset_captured_queries

  def reset_captured_queries
    ActiveRecord::Base.connection.class.clear_captured_queries
  end

  # Asserts that the expected number of queries were executed. The captured queries are
  # cleared before running the supplied block.
  def assert_num_queries(expected, message = nil)
    queries = capture_queries { yield }
    actual = queries.size
    message = build_message(message, "Expected <?> queries, but was <?>\n?", expected, actual, queries)
    assert_block(message) { actual == expected }
  end

  # Asserts that the executed queries matched a regular expression a certain number of
  # times.
  def assert_queries_matched_times(regex, times, message = nil)
    queries = capture_queries { yield }
    matching = queries.grep(regex)
    message = build_message(message, "Expected <?> queries matching <?>, but was <?>\nMatched: ?\nAll: ?", times, regex, matching.size, matching, queries)
    assert_block(message) { matching.size == times }
  end

  def assert_query_never_matched(regex, message = nil)
    assert_queries_matched_times(regex, 0, message) { yield }
  end

  def assert_query_called(query, times, message = nil)
    queries = capture_queries { yield }
    matching = queries.select {|x| x == query.strip}
    message = build_message(message, "Expected <?> queries equaling <?>, but was <?>\nMatched: ?\nAll: ?", times, query, matching.size, matching, queries)
    assert_block(message) { matching.size == times }
  end

  def capture_queries
    queries = capture_raw_queries { yield }
    queries.map {|x| x.to_sql.squeeze(' ').strip}
  end

  def capture_raw_queries
    reset_captured_queries
    yield
    ActiveRecord::Base.connection.class.queries
  end
end
