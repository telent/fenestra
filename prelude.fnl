((require "fun"))
(local fennelview (require "fennelview"))

;; this happens to be destructive but the caller should not depend on it
(lambda merge [old-value new-value]
  (each [k v (pairs new-value)]
    (tset old-value k v))
  old-value)

;; this happens to be destructive but the caller should not depend on it
(lambda conj [coll v]
  (table.insert coll v)
  coll)

(lambda inc [x] (+ x 1))
(lambda dec [x] (- x 1))

(assert (= 6 (sum (filter (lambda [x] (< x 3)) [1 7 1 9 2 10 2 4]))))

;; these are probably not the fastest way of doing this as I suspect
;; it does a lot of copying and makes a lot of garbage

(lambda empty? [c] (is_null c))

(fn id [x] x)

(lambda first [xs] (if (is_null xs) nil (head xs)))

(lambda keys [tbl]
  (let [out []]
    (each [k _ (pairs tbl)]
      (table.insert out k))
    out))

(lambda equal? [a b]
  (if (= (type a) (type b))
      (if (= (type a) "table")
          (and (= (length a) (length b))
               (every (fn [k] (equal? (. a k) (. b k)))
                      (keys a)))
          (= a b))
      false))

(assert (not (= 1 nil)) "1 is not nil")
(assert (equal? [6 1 2 3] [6 1 2 3]))
(assert (not  (equal? [1 2 3] [1 2 3 4])) "different lengths")
(assert (not (equal? {:l 2} {:l 2 :a 9})))
(assert (not (equal? {:l 2 :a 9} {:l 2})))
(assert (equal? {:l 2} {:l 2 }))

(lambda assert-equal [expected actual]
  (assert (equal? expected actual)
          (.. "test failed: "
              (fennelview
               {:expected expected
                :actual actual}))))

(fn assoc [tbl k v ...]
  (tset tbl k v)
  (if ...
      (assoc tbl (unpack [...]))
      tbl))

(assert-equal {:foo 1 :bar 34}
              (assoc {:foo 1}
                     :bar 34))

(assert-equal {:foo 1 :bar 34 :baz 6}
              (assoc {:foo 1}
                     :bar 34
                     :baz 6))

(lambda assoc-in [tbl path value]
  (let [k (head path)
        r (tail path)]
    (if (empty? r)
        (assoc tbl k value)
        (assoc tbl k (assoc-in (or (. tbl k) {}) r value)))))

(assert-equal {:k 2}
              (assoc-in {} [:k] 2))

(assert-equal {:horse {:zebra 9} }
              (assoc-in {} [:horse :zebra] 9))

(assert-equal {:horse {:zebra 9} }
              (assoc-in {:horse {:zebra 11}} [:horse :zebra] 9))

(assert-equal {:k {:l 2 :z 9} }
              (assoc-in {:k {:z 9}} [:k :l] 2))

(local fennel (require :fennel))
{
 :assoc assoc
 (fennel.mangle :assoc-in) assoc-in
 :conj conj
 :dec dec
 :empty? empty
 :equal? equal
 :inc inc
 :keys keys
 :merge merge
 }
