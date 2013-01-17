
class KtransientURL
  class << self
    @@entries = {}

    def [](id)
      @@entries[id.to_i]
    end

    def <<(hash)
      url_id = gen_url_id
      @@entries[url_id] = hash unless @@entries.has_value?(hash)
      return url_id
    end

    # Largest prime < 2^16 (maximum value of 2 bytes)
    # Pad 1000 (1s = 1000ms)
    # Random 'enough' for this purpose since it is transient and ligthweigth
    def gen_url_id
      (rand() * 1000).to_i + epoch_time.modulo(65521)
    end

    # Dump hash
    # __to a DB when Kibana supports storage?
    def entries
      @@entries
    end

    private

    def epoch_time
      return Time.now.to_i
    end
  end
end
