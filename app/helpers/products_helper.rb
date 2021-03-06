# encoding: utf-8
module ProductsHelper
  
  
  def product_rounded_price(product)
    if product.on_sale?
      "<span class='former_price'>#{pretty_price(product.taxed_price.rounded + product.rebate.rounded)}</span><br>"\
      "<span class='reduced_price'>#{pretty_price(product.taxed_price.rounded)}</span>"
    else
      pretty_price(product.taxed_price.rounded)
    end
      
  end
 
  def pretty_margin(product)
    if (product.purchase_price > 0 and product.margin > 0)
      if product.componentized?
        percent_string = product.calculated_margin_percentage.round(3).to_s
      else
        percent_string = ((100/product.purchase_price) * product.margin).round(3).to_s
      end
      
       string = sprintf "%.2f", product.margin
       pretty_margin = percent_string + "% = " + string
    else
      return sprintf "%.2f", 0
    end
  end
  
  def pretty_taxes(product)
    string = sprintf "%.2f", product.taxes
    product.tax_class.percentage.round(3).to_s + "% = " + string
  end
  
  
  def sortable_header(string, field)
   old_params = params.clone
   new_params = params.clone
 
    # We're on the same field, so we want to reverse sort order
    if old_params['ofield'] == field
      if old_params['odir'] == "DESC"
        new_params['odir'] = "ASC"
      elsif old_params['odir'] == "ASC"
        new_params['odir'] = "DESC"
      else
        new_params['odir'] = "ASC"
      end
    end
    
    new_params['ofield'] = field
    return link_to string, new_params
  end

  def product_link(url)
    return link_to "Herstellerlink", url
  end

  def attachment_links(product)
    html = ""
    if product.attachments.count > 0
      product.attachments.each_with_index do |att, i|
        unless att.file.to_s.blank?
          number = nil
          number = " #{i + 1}" unless i == 0
          html += "<li>" + link_to("Datenblatt#{number}", att.file.url) + "</li>\n"
        end
      end
    end
    return html
  end

  def show_stock(product)
    if product.is_build_to_order?
      html = "<div id='build_to_order_box'>"
      html += "<h4>Fertigung nach Auftrag</h4>"
      html += "<ul><li>Montage in der Schweiz</li>"
      html += "<li>Kundenwünsche möglich</li></ul>"
      html += "</div>"
      return html
    else
      if product.stock == 0
        return "<p>" + t('stizun.product.not_in_stock') + "</p>"
      else
        return "<p>" + product.stock.to_s + " " + t('stizun.product.pcs_in_stock_short') + "</p>"
      end
    end
  end
  

  def product_to_mailto(product)
    subject = "Beratung erwünscht zu '#{product.name}'"
    body =  "Liebe Lincomp\n\n"
    body += "Ich habe folgendes Produkt in Ihrem Shop entdeckt:\n\n"
    body += "#{product.name}, Lincomp-ID: #{product.id}\n\n"
    body += "Bitte beantworten Sie mir dazu folgende Fragen:\n\n"
    return mail_to "info@lincomp.ch", "Beratung zu diesem Produkt", :subject => subject, :body => body
  end

end
