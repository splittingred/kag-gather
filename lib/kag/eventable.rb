require 'active_support/core_ext/module/attribute_accessors'

module KAG
  module Eventable
    mattr_accessor :events
    def self.included(base)
        base.send :extend, ClassMethods
    end

    module ClassMethods
      def event(method,exp,occurring = :all)
        Eventable.events = {:live => {},:all => {},:warmup => {}} unless Eventable.events
        Eventable.events[occurring.to_sym] = {} unless Eventable.events[occurring.to_sym]
        if exp.class == Array
          exp.each do |e|
            Eventable.events[occurring.to_sym][e] = method.to_sym
          end
        else
          Eventable.events[occurring.to_sym][exp] = method.to_sym
        end
      end
    end

    def process_event(msg)
      found = false
      Eventable.events[:all].each do |exp,method|
        if _test_event(msg,exp)
          found = self.send(method,msg)
          break
        end
      end
      if !found and self.live
        Eventable.events[:live].each do |exp,method|
          if _test_event(msg,exp)
            found = self.send(method,msg)
            break
          end
        end
      elsif !found
        Eventable.events[:warmup].each do |exp,method|
          if _test_event(msg,exp)
            found = self.send(method,msg)
            break
          end
        end
      end
      found
    end

    protected

    def _test_event(msg,exp)
      if msg.class == String
        !msg.index(exp).nil?
      else
        msg.match(exp)
      end
    end
  end
end