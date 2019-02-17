;(global each {}) 
(local fun (require "fun"))

(local fennelview (require "fennelview"))
(global pp (lambda [x] (print (fennelview x))))

(local p (require "prelude"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


;; the graph is a map of node => value

(fn add-node [graph node]
  (tset graph node {}))

;; technically, a sink is just a node without local value
;; (technically^2 it might accidentally have a value in the table,
;;  but its handler functon is invoked without passing that value in)
(fn add-sink [graph sink]
  (let [h sink.handler
        f (fn [_ val]
            (h  val))]
    (tset graph (p.assoc sink :handler f) {} )))

(fn counting-graph [outval]
  (doto {}
    (add-node {:attributes {:name :counter}
               :events [:count]
               :handler (fn [a message]
                          (let [i (p.inc (or a.counter 0))]
                            (values {:counter i} i)))})
    (add-sink {:attributes {:name :sink}
               :events []
               :inputs [{:name :counter}]
               :handler (fn [message]   ;sinks dont have state
                          (tset outval :fred message))})))

(fn includes? [big-table small-table]
  (fun.every (fn [k v] (= (. big-table k) v))
             small-table))

(assert (includes? {:a 1 :b 2} {:a 1}))
(assert (not (includes? {:a 1 :b 2} {:a 2})))
(assert (not (includes? {:a 1 :b 2} {:c 2})))


(fn find-event-subscribers [graph event]
  (fun.filter (fn [node value]
                (fun.any (fn [i] (= i event)) node.events ))
              graph))

(fn find-node-watchers [graph node]
  ;; find nodes whose inputs contain some element matching
  ;; the node.
  ;; by 'match' we mean that every k/v pair in the input matches
  ;; a pair in the node, but the node may have other keys/values
  ;; as well
  (fun.filter (fn [n value]
                (fun.any (fn [i]
                           (includes? node.attributes i))
                         (or n.inputs [] )))
              graph))

(assert (= (. 
            (fun.head
             (find-node-watchers (counting-graph {})
                                 {:attributes {:name :counter}}))
            :attributes :name )
           :sink))

(fn run-nodes [graph message rcpts]
  (fun.reduce
   (fn [m node value]
     (let [h node.handler
           (v m) (h value message)
           w (find-node-watchers graph node)]
       (tset graph node (or v {}))
       (run-nodes graph m w)
       m))
   {}
   rcpts))

(fn dispatch [graph event]
  (run-nodes graph event (find-event-subscribers graph event)))

(local fennel (require :fennel))

(fn test-counter []
  (let [outval {:fred 0}
        graph (counting-graph outval)]
    (dispatch graph :count)
    (dispatch graph :count)
    (dispatch graph :count)
    (dispatch graph :count)
    (dispatch graph :count)
    (p.assert_equal 5 outval.fred)))
  
(test-counter)      
