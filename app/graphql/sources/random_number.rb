require "async/http/internet/instance"

module Sources
  class RandomNumber < GraphQL::Dataloader::Source
    def fetch(limits)
      limits.map do |limit|
        Async do
          Async::HTTP::Internet.get("https://www.random.org/integers/?num=1&min=1&max=#{limit}&col=1&base=10&format=plain&rnd=new").read.to_i
        end
      end.map(&:wait)
    end
  end
end
