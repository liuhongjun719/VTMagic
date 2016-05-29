//
//  VTCategoryBar.m
//  VTMagicView
//
//  Created by tianzhuo on 15/1/6.
//  Copyright (c) 2015年 tianzhuo. All rights reserved.
//

#import "VTCategoryBar.h"
#import "UIScrollView+Magic.h"
#import "VTCommon.h"

@interface VTCategoryBar()

@property (nonatomic, strong) NSMutableArray *frameList; // frame数组
@property (nonatomic, strong) NSMutableDictionary *visibleDict; // 屏幕上可见的cat item
@property (nonatomic, strong) NSMutableSet *cacheSet; // 缓存池
@property (nonatomic, strong) NSMutableDictionary *cacheDict; // 缓存池
@property (nonatomic, strong) NSString *identifier; // 重用标识符
@property (nonatomic, strong) NSMutableArray *indexList; // 索引集合
@property (nonatomic, strong) UIFont *itemFont;

@end

@implementation VTCategoryBar

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
        _itemBorder = 25.f;
        _indexList = [[NSMutableArray alloc] init];
        _frameList = [[NSMutableArray alloc] init];
        _visibleDict = [[NSMutableDictionary alloc] init];
        _cacheSet = [[NSMutableSet alloc] init];
    }
    return self;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
    
    UIButton *itemBtn = nil;
    CGRect frame = CGRectZero;
    NSArray *indexList = [_visibleDict allKeys];
    for (NSNumber *index in indexList) {
        itemBtn = _visibleDict[index];
        frame = [_frameList[[index integerValue]] CGRectValue];
        if (![self vtm_isNeedDisplayWithFrame:frame]) {
            [itemBtn setSelected:NO];
            [itemBtn removeFromSuperview];
            [_visibleDict removeObjectForKey:index];
            [_cacheSet addObject:itemBtn];
        } else {
            itemBtn.selected = NO;
            itemBtn.frame = frame;
        }
    }
    
    NSMutableArray *leftIndexList = [_indexList mutableCopy];
    [leftIndexList removeObjectsInArray:indexList];
    for (NSNumber *index in leftIndexList) {
        frame = [_frameList[[index integerValue]] CGRectValue];
        if ([self vtm_isNeedDisplayWithFrame:frame]) {
            itemBtn = [_datasource categoryBar:self categoryItemForIndex:[index integerValue]];
            if (![itemBtn isKindOfClass:[UIButton class]]) continue;
            [itemBtn addTarget:self action:@selector(catItemClick:) forControlEvents:UIControlEventTouchUpInside];
            itemBtn.tag = [index integerValue];
            itemBtn.frame = frame;
            itemBtn.selected = NO;
            [self addSubview:itemBtn];
            [_visibleDict setObject:itemBtn forKey:index];
        }
    }
    
    _selectedItem = _visibleDict[@(_currentIndex)];
    _selectedItem.selected = YES;
}

- (id)dequeueReusableCatItemWithIdentifier:(NSString *)identifier
{
    _identifier = identifier;
    UIButton *catItem = [_cacheSet anyObject];
    if (catItem) {
        [_cacheSet removeObject:catItem];
    }
    return catItem;
}

#pragma mark - 更新选中按钮
- (void)updateSelectedItem
{
    _selectedItem.selected = NO;
    _selectedItem = _visibleDict[@(_currentIndex)];
    _selectedItem.selected = YES;
}

#pragma mark - 重新加载数据
- (void)reloadData
{
    [self resetCacheData];
    [self resetFrames];
    [self setNeedsLayout];
}

-(void)resetCacheData
{
    [_indexList removeAllObjects];
    NSInteger pageCount = _catNames.count;
    for (NSInteger index = 0; index < pageCount; index++) {
        [_indexList addObject:@(index)];
    }
    
    NSArray *visibleItems = [_visibleDict allValues];
    for (UIButton *itemBtn in visibleItems) {
        [itemBtn setSelected:NO];
        [itemBtn removeFromSuperview];
        [_cacheSet addObject:itemBtn];
    }
    [_visibleDict removeAllObjects];
}

#pragma mark - 重置所有frame
- (void)resetFrames
{
    [_frameList removeAllObjects];
    
    UIButton *catItem = nil;
    if (!_itemFont && _catNames.count) {
        catItem = [self createItemWithIndex:_currentIndex];
        _itemFont = catItem.titleLabel.font;
    }
    
    if (_autoResizing) {
        [self autoResizingMode];
    } else {
        [self defaultResetMode];
    }
    
    CGFloat contentWidth = CGRectGetMaxX([[_frameList lastObject] CGRectValue]);
    self.contentSize = CGSizeMake(contentWidth, 0);
    if (catItem && _currentIndex < _frameList.count) {
        catItem.frame = [_frameList[_currentIndex] CGRectValue];
    }
}

- (void)defaultResetMode
{
    CGFloat itemX = 0;
    CGSize size = CGSizeZero;
    CGRect frame = CGRectZero;
    NSInteger count = _catNames.count;
    CGFloat height = self.frame.size.height;
    for (int index = 0; index < count; index++) {
        if (iOS7_OR_LATER) {
            size = [_catNames[index] sizeWithAttributes:@{NSFontAttributeName : _itemFont}];
        } else {
            size = [_catNames[index] sizeWithFont:_itemFont];
        }
        frame = CGRectMake(itemX, 0, size.width + _itemBorder, height);
        [_frameList addObject:[NSValue valueWithCGRect:frame]];
        itemX += frame.size.width;
    }
}

- (void)autoResizingMode
{
    CGRect frame = CGRectZero;
    NSInteger count = _catNames.count;
    CGFloat height = self.frame.size.height;
    CGFloat itemWidth = CGRectGetWidth(self.frame)/count;
    for (int index = 0; index < count; index++) {
        frame = CGRectMake(itemWidth * index, 0, itemWidth, height);
        [_frameList addObject:[NSValue valueWithCGRect:frame]];
    }
}

#pragma mark - 查询
- (CGRect)itemFrameWithIndex:(NSInteger)index
{
    if (index < 0 || _frameList.count <= index) return CGRectNull;
    return [_frameList[index] CGRectValue];
}

- (UIButton *)itemWithIndex:(NSInteger)index
{
    return [self itemWithIndex:index autoCreateForNil:NO];
}

- (UIButton *)createItemWithIndex:(NSInteger)index
{
    return [self itemWithIndex:index autoCreateForNil:YES];
}

- (UIButton *)itemWithIndex:(NSInteger)index autoCreateForNil:(BOOL)autoCreate
{
    if (index < 0 || _catNames.count <= index) return nil;
    UIButton *catItem = _visibleDict[@(index)];
    if (autoCreate && !catItem) {
        catItem = [_datasource categoryBar:self categoryItemForIndex:index];
        if (!catItem) return nil;
        catItem.tag = index;
        [self addSubview:catItem];
        [_visibleDict setObject:catItem forKey:@(index)];
        if (index < _frameList.count) catItem.frame = [_frameList[index] CGRectValue];
        [catItem addTarget:self action:@selector(catItemClick:) forControlEvents:UIControlEventTouchUpInside];
    }
    return catItem;
}

#pragma mark - item 点击事件
- (void)catItemClick:(id)sender
{
    NSInteger newIndex = [(UIButton *)sender tag];
    if (newIndex == _currentIndex) return;
    if ([_catDelegate respondsToSelector:@selector(categoryBar:didSelectedItem:)]) {
        [_catDelegate categoryBar:self didSelectedItem:sender];
    }
}

#pragma mark - accessor
- (void)setItemBorder:(CGFloat)itemBorder
{
    _itemBorder = itemBorder;
    if (_catNames.count) {
        [self resetFrames];
    }
}

@end