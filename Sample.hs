dict1 = [("Allen", 1), ("Bob", 2)]
dict2 = [("Cindy", 3), ("Dale", 4)]
dict3 = [("Emma", 5), ("Frank", 6), ("Gary", 7)]

dicts = [dict1, dict2, dict3]

-- how to lookup in all dicts

lookupK :: Eq a => a -> [(a, b)] -> (a -> r) -> (b -> r) -> r
lookupK key dict ck cv = case lookup key dict of
  Nothing -> ck key
  Just value -> cv value

lookupInDictsK :: Eq a => a -> [[(a, b)]] -> (a -> r) -> (b -> r) -> r
lookupInDictsK key [] ck cv = ck key
lookupInDictsK key (dict:dicts) ck cv = lookupK key dict (\key -> lookupInDictsK key dicts ck cv) cv

lookupInDicts :: Eq a => a -> [[(a, b)]] -> Maybe b
lookupInDicts key dicts = lookupInDictsK key dicts (const Nothing) Just

lookupInDicts' :: Eq a => a -> [[(a, b)]] -> Maybe b
lookupInDicts' key [] = Nothing
lookupInDicts' key (dict:dicts) = case lookup key dict of
  Nothing -> lookupInDicts' key dicts
  Just value -> Just value