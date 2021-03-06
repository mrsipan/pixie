(ns pixie.io.uv-common
  (:require [pixie.stacklets :as st]
            [pixie.uv :as uv]
            [pixie.ffi :as ffi]))

(defn cb-stream-reader [uv-client buffer len]
  (assert (<= (buffer-capacity buffer) len)
          "Not enough capacity in the buffer")
  (let [alloc-cb (uv/-prep-uv-buffer-fn buffer len)
        read-cb (atom nil)]
    (st/call-cc (fn [k]
                  (reset! read-cb (ffi/ffi-prep-callback
                                    uv/uv_read_cb
                                    (fn [stream nread uv-buf]
                                      (set-buffer-count! buffer nread)
                                      (try
                                        (dispose! alloc-cb)
                                        (dispose! @read-cb)
                                        ;(dispose! uv-buf)
                                        (uv/uv_read_stop stream)
                                        (st/run-and-process k (or
                                                                (st/exception-on-uv-error nread)
                                                                nread))
                                        (catch ex
                                          (println ex))))))
                  (uv/uv_read_start uv-client alloc-cb @read-cb)))))

(defn cb-stream-writer 
  [uv-client uv-write-buf buffer]
  (let [write-cb (atom nil)
          uv_write (uv/uv_write_t)]
      (ffi/set! uv-write-buf :base buffer)
      (ffi/set! uv-write-buf :len (count buffer))
      (st/call-cc
       (fn [k]
         (reset! write-cb (ffi/ffi-prep-callback
                          uv/uv_write_cb
                          (fn [req status]
                            (try
                              (dispose! @write-cb)
                              ;(uv/uv_close uv_write st/close_cb)
                              (st/run-and-process k status)
                              (catch ex
                                  (println ex))))))
         (uv/uv_write uv_write uv-client uv-write-buf 1 @write-cb)))))
