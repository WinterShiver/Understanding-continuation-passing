# Understanding-continuation-passing
理解CPS中continuation passing的概念（使用Haskell描述）

# 前言

接触CPS有一段时间了，知道CPS就是把值`2`写成`\f -> f 2`，传入的参数`f`是接下来要对值`2`进行的后续操作过程，所以把这里的`f`称为continuation。然而，我一直不知道这玩意为什么叫做continuation——我不知道这东西所指的“后续操作”是从哪里来的，不知道为什么计算要用这种方式延续。今天在学习The Little Schemer的时候终于找到了一个令我信服的应用场景，所以写篇博客说明一下这件事。

这篇博客的问题来自Scheme，本来想用Python解释的，但是无奈Scheme欠缺好用的数据结构和标准方法，Python欠缺好用的FP特性，最后不得已还是用Haskell做了这篇文章的阐述。不得不说Haskell在解释FP的相关问题的时候还是很有优势的。

# 正文

**问题的提出**

现在我们有三个班级的名单，记录人名-学号对应关系，用`[(String, Int)]`类型的变量存储。

```haskell
dict1 = [("Allen", 1), ("Bob", 2)]
dict2 = [("Cindy", 3), ("Dale", 4)]
dict3 = [("Emma", 5), ("Frank", 6), ("Gary", 7)]
```

如果是实际情况，名单的数量可能还有更多，所以我们把所有的名单放在一个列表里：

```python
dicts = [dict1, dict2, dict3]
```

如果在同一个名单里面查询，使用`lookup :: Eq a => a -> [(a, b)] -> Maybe b`就可以。看函数签名就知道`lookup`的行为了。例如，我们想要查询学生`"Allen"`的学号，就直接传入`lookup`进行查询。

```haskell
*Main> lookup "Allen" dict1
Just 1
*Main> lookup "Allen" dict2
Nothing
```

在`dict1`中能找到`"Allen"`的值`1`，所以返回`Just 1`，在`dict2`中找不到所以返回`Nothing`.

那么如果是在所有的`dict`中查询这个`key`呢？我们可以递归地从`dicts`中拿出每一个`dict`做`lookup`，代码如下：

```haskell
lookupInDicts' :: Eq a => a -> [[(a, b)]] -> Maybe b
lookupInDicts' key [] = Nothing
lookupInDicts' key (dict:dicts) = case lookup key dict of
  Nothing -> lookupInDicts' key dicts
  Just value -> Just value
```

可以看到，程序执行的顺序是，先对`dicts`头部的`dict`进行`lookup`，如果匹配到则返回`value`，如果匹配失败则继续对`dicts`的剩余部分执行`lookupInDicts'`。对这个顺序，我们可以理解成，对`dicts`的剩余部分进行`lookupInDicts'`是`key`对`dict`进行`lookup`失败后，对`key`继续进行的计算。也就是说，`lookupInDicts' key dicts`就是`lookup key dict`失败后的continuation。

认识到这个观点之后，我们来写`lookupInDicts`的CPS版本，来把这一点表达出来。

**lookup的CPS版本**

首先我们需要写`lookup :: Eq a => a -> [(a, b)] -> Maybe b`的CPS版本，记为`lookupK`。

我们首先确定`lookupK`的参数。`lookup`有成功和失败的可能，如果成功能获得一个`value :: b`的信息，如果失败会返回一个`Nothing`。我们希望`lookupK`在成功时处理一个类型为`b`的信息（也就是找到的value），在失败时处理一个类型为`a`的信息（也就是原来的key）。所以相对给`lookup`的两个参数`key :: a`和`dict :: [(a, b)]`，我们需要再给两个参数`ck :: a -> r`和`cv :: b -> r`用来在失败和成功的情况下做处理，最终返回`r`类型的返回值。所以我们确定了`lookupK`的签名和定义如下：

```haskell
lookupK :: Eq a => a -> [(a, b)] -> (a -> r) -> (b -> r) -> r
lookupK key dict ck cv = case lookup key dict of
  Nothing -> ck key
  Just value -> cv value
```

**lookupInDicts的CPS版本**

对于`lookupInDictsK`，很明显它的签名就是把`dict`的`[(a, b)]`换成`dicts`的`[[(a, b)]]`，其他保持不变，所以它的定义就是对`lookupInDicts key dicts ck cv`值的确定。

我们先把比较简单的部分写出来。

```haskell
lookupInDictsK :: Eq a => a -> [[(a, b)]] -> (a -> r) -> (b -> r) -> r
lookupInDictsK key [] ck cv = ck key
lookupInDictsK key (dict:dicts) ck cv = ？
```

我们接下来要说的事情是，在`dicts`不为`[]`的时候（此时不妨把这个参数表示成`dict:dicts`，它的`head`是`dict`），`lookupInDictsK key (dict:dicts) ck cv`是可以通过`lookupK key dict ck' cv'`来定义的。因为`ck'`对应了`lookup key dict`不成功之后做的事，所以只需要将之后对列表后续部分的匹配过程传入`ck'`就可以了。

具体是这样的：如上文所说，我们把`key`对词典列表剩余部分（`dicts`）的匹配视为一种continuation，所以我们可以把这个过程作为`cv'`传入`lookupK`。在第一步的`lookupK key dict ck' cv'`中，如果`lookup`成功则拿到`Just value`而正常执行`cv`，所以`cv'`就是`cv`；如果失败则拿出`key`执行`lookupInDicts key dicts ck cv`，那么`ck'`是`\key -> lookupInDicts key dicts ck cv`. 

确定了`ck'`和`cv'`就可以得到最后的定义：

```haskell
lookupInDictsK :: Eq a => a -> [[(a, b)]] -> (a -> r) -> (b -> r) -> r
lookupInDictsK key [] ck cv = ck key
lookupInDictsK key (dict:dicts) ck cv = lookupK key dict (\key -> lookupInDictsK key dicts ck cv) cv
```

通过这个定义，我们做到了：将一个过程描述为一个预先的子过程，然后为这个子过程产生的结果提供一个continuation，执行得到最后的结果。

确定`r`为`Maybe b`之后补充`ck`和`cv`，就得到了与先前非CPS定义行为一致的`lookupInDicts`。

```haskell
lookupInDicts :: Eq a => a -> [[(a, b)]] -> Maybe b
lookupInDicts key dicts = lookupInDictsK key dicts (const Nothing) Just
```

效果：

```haskell
*Main> lookupInDicts "Emma" dicts
Just 5
*Main> lookupInDicts "Emmaa" dicts
Nothing
```

**思路总结**

在写出`lookupInDictsK`之后，为了进一步说明这个函数的思路，重新放一下上面实现的各个函数。

```haskell
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
```

`lookupInDictsK key dicts ck cv`就是拿出`dicts`中每一个`dict`，拿`key`进行查询，一旦成功则把拿到的`value`传给`cv`得到结果，而如果全部不成功则把原始的`key`传给`ck`得到结果。

在词典列表为空时，最终的查询显然会失败，所以返回`ck key`。

在词典列表非空时，我们把查询的第一个环节抽取出来，即拿出`key`和词典列表第一个元素`dict`做`lookup`。第一个环节如果成功了就直接把拿到的值传给`cv`出结果，如果不成功则继续对词典列表的剩余部分做`lookuoInDicts`。以上部分的语义和我们定义的`lookupK`是契合的，所以我们只需要给`lookupK`以合适的参数，就可以基于`lookupK`定义`lookupInDicts`. 

具体而言，在词典列表非空时，我们可以把定义写作`lookupInDictsK key (dict:dicts) ck cv = lookupK key dict ck' cv'`. 在`lookup`成功时，我们给`cv'`输入的参数是query到的值`value`，期望它输出的值是`cv value`，所以`cv'`就是`cv`；在失败时，我们给`ck'`输入的值是原始键值`key`，期望他做的事情是拿`key`和列表剩余部分`dicts`做`lookup`，所以期望的输出值是`lookupInDIctsK key dicts ck cv`，那么`ck' = \key -> lookupInDIctsK key dicts ck cv`，从而得到我们定义中的`lookupInDictsK key (dict:dicts) ck cv = lookupK key dict (\key -> lookupInDictsK key dicts ck cv) cv`。

# 总结

`\key -> lookupInDictsK key dicts ck cv`是一个非常典型的continuation，因为这个函数能让人意识到，传给CPS值的函数并不只能是我们常见的collector，还可以是一个continuation（输入的函数会把被CPS类型包裹的值送入下一项处理，而不仅是把这个值收集起来）。collection可以视为对 值最终做的一件事（把值收集起来的行为可以视为对这个值的最后一项处理）。充分理解这一点之后，就能更好地利用CPS类型的值解决问题了。

本文所使用的代码见于Sample.hs. 