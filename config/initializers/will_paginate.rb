WillPaginate::ViewHelpers.pagination_options[:previous_label] = '&lt;&lt;'
WillPaginate::ViewHelpers.pagination_options[:next_label] = '&gt;&gt;'

module WillPaginate
  module ViewHelpers
    class LinkRenderer < LinkRendererBase

      protected
      def gap
        text = "&hellip;"
        %(<span class="gap">#{text}</span>)
      end
    end
  end
end
