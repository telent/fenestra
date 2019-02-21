;; the graph is a map of node => value

(fn add-node [graph node]
  (tset graph node {}))

;; technically, a sink is just a node without local value
;; (technically^2 it might accidentally have a value in the table,
;;  but its handler function is invoked without passing that value in)
(fn add-sink [graph sink]
  (let [h sink.handler
        f (fn [_ val]
            (h  val))]
    (tset graph (assoc sink :handler f) {} )))

(fn counting-graph [outval]
  (doto {}
    (add-node {:attributes {:name :counter}
               :events [:count]
               :handler (fn [a message]
                          (let [i (inc (or a.counter 0))]
                            (values {:counter i} i)))})
    (add-sink {:attributes {:name :sink}
               :events []
               :inputs [{:name :counter}]
               :handler (fn [message]   ;sinks dont have state
                          (tset outval :fred message))})))

(fn includes? [big-table small-table]
  (every (fn [k v] (= (. big-table k) v))
         small-table))

(assert (includes? {:a 1 :b 2} {:a 1}))
(assert (not (includes? {:a 1 :b 2} {:a 2})))
(assert (not (includes? {:a 1 :b 2} {:c 2})))


(fn find-event-subscribers [graph event]
  (filter (fn [node value]
            (any (fn [i] (= i event)) node.events ))
          graph))

(fn find-node-watchers [graph node]
  ;; find nodes whose inputs contain some element matching
  ;; the node.
  ;; by 'match' we mean that every k/v pair in the input matches
  ;; a pair in the node, but the node may have other keys/values
  ;; as well
  (filter (fn [n value]
            (any (fn [i]
                   (includes? node.attributes i))
                 (or n.inputs [] )))
          graph))

(assert (= (. 
            (head
             (find-node-watchers (counting-graph {})
                                 {:attributes {:name :counter}}))
            :attributes :name )
           :sink))

(fn run-nodes [graph message rcpts]
  (reduce
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
