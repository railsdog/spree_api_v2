describe Spree::Api::V2::LineItemsController do
  routes { Spree::Core::Engine.routes }

  let(:order) { create :order }
  let(:user) { order.user }
  let(:variant) { create :variant }

  before { user.generate_spree_api_key! }

  describe '#create' do
    let(:line_item_params) { { order_id: order.id, variant_id: variant.id, quantity: 1 } }

    context 'on success' do
      it 'will respond with line item' do
        post :create, token: user.spree_api_key, line_item: line_item_params
        expect(JSON.parse(response.body)['data']['type']).to eql 'spree_line_items'
      end
    end

    context 'when out of range' do
      before do
        post :create, token: user.spree_api_key,
                      line_item: line_item_params.merge(quantity: 123_123_123_123)
      end

      it 'will respond with quantity too high error' do
        expect(response.body).to be_json_eql <<-JSON
          {
            "errors" : [
              {
                "detail" : #{Spree.t('api.errors.quantity_too_high.detail').gsub("\n", '').to_json},
                "meta" : {},
                "title" : #{Spree.t('api.errors.quantity_too_high.title').titleize.to_json}
              }
            ]
          }
        JSON
      end
    end

    context 'when record not found' do
      before do
        post :create, token: user.spree_api_key, line_item: line_item_params.merge(order_id: 0)
      end

      it 'will respond with record not found error' do
        expect(response.body).to be_json_eql <<-JSON
          {
            "errors" : [
              {
                "detail" : #{Spree.t('api.errors.record_not_found.detail').gsub("\n", '').to_json},
                "meta" : {},
                "title" : #{Spree.t('api.errors.record_not_found.title').to_json}
              }
            ]
          }
        JSON
      end
    end

    context 'when record is invalid' do
      let(:stock_item) { variant.stock_items.first }

      before do
        quantity = stock_item.count_on_hand + 1
        stock_item.update(backorderable: false)
        post :create, token: user.spree_api_key,
                      line_item: line_item_params.merge(quantity: quantity)
      end

      it 'will respond with product out of stock' do
        expect(response.body).to be_json_eql <<-JSON
          {
            "errors" : [
              {
                "detail" : "#{Spree.t('api.errors.product_out_of_stock.detail').gsub("\n", '')}",
                "meta" : {},
                "title" : #{Spree.t('api.errors.product_out_of_stock.title').titleize.to_json}
              }
            ]
          }
        JSON
      end
    end
  end
end
