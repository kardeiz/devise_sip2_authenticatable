require 'devise_sip2_authenticatable/strategy'

module Devise
  module Models
    module Sip2Authenticatable
      extend ActiveSupport::Concern
      included do
        attr_reader :current_password, :password
        attr_accessor :password_confirmation
      end
      
      def password=(new_password)
        @password = new_password
        if defined?(password_digest) && @password.present? && respond_to?(:encrypted_password=)
          self.encrypted_password = password_digest(@password) 
        end
      end      
      
      def sip2_auth_hash(auth_key_value, password)
        s = Devise::Sip2.new
        s.get_patron_information(:patron => auth_key_value, :patron_pwd => password)
      end
      
      module ClassMethods
        def authenticate_with_sip2(attributes={})
          auth_key = self.authentication_keys.first
          return nil unless attributes[auth_key].present?
          auth_key_value = if self.case_insensitive_keys.try :include?, auth_key
            attributes[auth_key].downcase
          else
            attributes[auth_key]
          end
          resource = where(auth_key => auth_key_value).first

          if resource.blank?
            resource = new
            resource[auth_key] = auth_key_value
          end
          
          sip2_obj = resource.sip2_auth_hash(auth_key_value, attributes[:password])
          
          if sip2_obj.delete(:valid)
            if resource.respond_to?(:sip2_before_save)
              resource.sip2_before_save(auth_key_value, attributes[:password]) 
            end
            resource.try(:assign_attributes, sip2_obj)
            resource.save! if resource.new_record? or resource.changed?
            return resource
          else
            return nil
          end
        end
      end
    end
  end
end
