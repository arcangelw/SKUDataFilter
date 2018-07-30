//
//  SKUStandardListFilter.m
//  SKU Demo
//
//  Created by 吴哲 on 2018/7/30.
//  Copyright © 2018年 arcangelw. All rights reserved.
//

#import "SKUDataFilter.h"

@interface SKUDataFilter()
/// originalConditions 原始数据
@property(nonatomic ,copy ,readwrite) NSSet<SKUFilterCondition *> *originalConditions;
/// filterConditions 自定义筛选后的数据
@property(nonatomic ,copy ,readwrite) NSSet<SKUFilterCondition *> *filterConditions;
/// allAvailableIndexPaths 所有可用的
@property(nonatomic ,copy ,readwrite) NSSet<NSIndexPath *> *allAvailableIndexPaths;

/// selectedIndexPaths
@property(nonatomic ,copy ,readwrite) NSMutableArray<NSIndexPath *> *selectedIndexPaths;
/// availableIndexPathsSet
@property(nonatomic ,copy ,readwrite) NSMutableSet<NSIndexPath *> *availableIndexPathsSet;
/// 还可以选择的数据
@property(nonatomic ,copy ,readwrite) NSMutableSet<SKUFilterCondition *> *availableConditions;
/// 当前筛选结果
@property(nonatomic ,strong ,readwrite) SKUFilterCondition *result;;
@end
@implementation SKUDataFilter

- (instancetype)initWithDataSource:(id<SKUDataFilterDataSource>)dataSource
{
    self = [super init];
    if (self) {
        _dataSource = dataSource;
        _selectedIndexPaths = @[].mutableCopy;
        [self initSelectedIndexPaths];
        [self initPropertiesSkuData];
        if (_selectedIndexPaths.count) {
            [self updateAvailableIndexPaths];
            [self updateResult];
        }
    }
    return self;
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _selectedIndexPaths = [NSMutableArray array];
    }
    return self;
}

- (void)setDataSource:(id<SKUDataFilterDataSource>)dataSource
{
    _dataSource = dataSource;
    [self initSelectedIndexPaths];
    [self initPropertiesSkuData];
    if (_selectedIndexPaths.count) {
        [self updateAvailableIndexPaths];
        [self updateResult];
    }
}

- (void)didSelectedPropertyWithIndexPath:(NSIndexPath *)indexPath
{
    /// 不可选
    if (![_availableIndexPathsSet containsObject:indexPath]) {
        return;
    }
    
    /// 越界
    if (indexPath.section >= [_dataSource numberOfSectionsForPropertiesInFilter:self] || indexPath.item >= [_dataSource filter:self propertiesInSection:indexPath.section].count) {
        NSLog(@"indexPath is out of range");
        return;
    }
    
    /// 已经选中 取消选中状态
    if ([_selectedIndexPaths containsObject:indexPath]) {
        [_selectedIndexPaths removeObject:indexPath];
        
        [self updateAvailableIndexPaths];
        [self updateResult];
        return;
    }
    
    /// 获取当前 选中section 上次选中索引
    __block NSIndexPath *sectionLastIndexPath = nil;
    [_selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (indexPath.section == obj.section) {
            sectionLastIndexPath = obj;
        }
    }];

    /// 上次结果存在
    if (sectionLastIndexPath) {
        ///切换
        [_selectedIndexPaths addObject:indexPath];
        [_selectedIndexPaths removeObject:sectionLastIndexPath];
        
    }else{
        ///添加
        [_selectedIndexPaths addObject:indexPath];
    }
    
    [self updateAvailableIndexPaths];
    [self updateResult];
}

- (void)reloadData
{
    [_selectedIndexPaths removeAllObjects];
    [self initPropertiesSkuData];
    [self updateResult];
}

- (BOOL)hasSelectedIndexPathInSection:(NSInteger)section
{
    if (section >= [_dataSource numberOfSectionsForPropertiesInFilter:self]) {
        return NO;
    }
    __block BOOL flag = NO;
    [_selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        if (obj.section == section) {
            flag = YES;
            *stop = YES;
        }
    }];
    return flag;
}

#pragma mark -
- (void)initPropertiesSkuData
{
    NSSet<id<SKUFilterConditionProtocol>> *skuDataSet = [_dataSource conditionsInFilter:self];
    NSInteger section = [_dataSource numberOfSectionsForPropertiesInFilter:self];
    __block NSMutableSet *conditionSet = [NSMutableSet set];
    __weak __typeof(&*self)weakSelf = self;
    [skuDataSet enumerateObjectsUsingBlock:^(id<SKUFilterConditionProtocol>  _Nonnull obj, BOOL * _Nonnull stop) {
        NSArray<SKUConditionType> *conditions = obj.conditions;
        NSParameterAssert(conditions.count == section);
        if (conditions.count != section && ![self checkConditions:conditions]) {
            NSLog(@"当前sku信息数据不正确\n %@",obj.description);
        }else{
            SKUFilterCondition *condition = [SKUFilterCondition new];
            condition.properties = [weakSelf propertiesWithCondition:conditions];
            condition.result = obj;
            [conditionSet addObject:condition];
        }
    }];
    _originalConditions = conditionSet.copy;
    _filterConditions = _originalConditions;
    if ([_dataSource respondsToSelector:@selector(customConditionsInFilter:originalConditions:)]) {
        _filterConditions = [_dataSource customConditionsInFilter:self originalConditions:_originalConditions];
    }
    
    [self getAllAvailableIndexPaths];
}

- (BOOL)checkConditions:(NSArray<SKUConditionType> *)conditions
{
    __block BOOL flag = YES;
    __weak __typeof(&*self)weakSelf = self;
    [conditions enumerateObjectsUsingBlock:^(SKUConditionType  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<SKUFilterPropertyProtocol> property = [weakSelf.dataSource filter:weakSelf propertiesInSection:idx propertyCondition:obj];
        ///校验sku数据 如果 ondition 不存在该属性 说明sku数据错误
        if (!property) {
            flag = NO;
            *stop = YES;
        }
    }];
    return flag;
}

- (NSArray<SKUFilterProperty *> *)propertiesWithCondition:(NSArray<SKUConditionType> *)conditions
{
    __block NSMutableArray<SKUFilterProperty *> *properties = @[].mutableCopy;
    __weak __typeof(&*self)weakSelf = self;
    [conditions enumerateObjectsUsingBlock:^(SKUConditionType  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [properties addObject:[weakSelf propertyInSection:idx propertyCondition:obj]];
    }];
    return properties.copy;
}

- (SKUFilterProperty *)propertyInSection:(NSInteger)section propertyCondition:(SKUConditionType)condition
{
    NSArray<id<SKUFilterPropertyProtocol>> *properties = [_dataSource filter:self propertiesInSection:section];
    id<SKUFilterPropertyProtocol> property = [_dataSource filter:self propertiesInSection:section propertyCondition:condition];
    NSParameterAssert(property != nil && [properties containsObject:property]);
    NSIndexPath *indexPath = [NSIndexPath indexPathForItem:[properties indexOfObject:property] inSection:section];
    return [SKUFilterProperty initWithValue:property indexPath:indexPath];
}

/// 通过索引 获取属性
- (id<SKUFilterPropertyProtocol>)getPropertyByIndexPath:(NSIndexPath *)indexPath
{
    NSArray<id<SKUFilterPropertyProtocol>> *properties = [_dataSource filter:self propertiesInSection:indexPath.section];
    NSParameterAssert(indexPath.item < properties.count);
    return  indexPath.item < properties.count ?properties[indexPath.item] : nil;
}

/// 获取条件 对应的sku数据
//- (id<SKUFilterConditionProtocol>)skuResultWithConditionIndexPaths:(NSArray<NSIndexPath *> *)conditionIndexPaths
//{
//    __block id<SKUFilterConditionProtocol> result = nil;
//    [_filterConditions enumerateObjectsUsingBlock:^(SKUFilterCondition * _Nonnull obj, BOOL * _Nonnull stop) {
//        if ([obj.conditionIndexPaths isEqual:conditionIndexPaths]) {
//            result = obj.result;
//            *stop = YES;
//        }
//    }];
//    return nil;
//}

/// 初始化选中状态
- (void)initSelectedIndexPaths
{
    __block NSMutableArray<NSIndexPath *> *selectedIndexPaths = @[].mutableCopy;
    NSInteger section = [_dataSource numberOfSectionsForPropertiesInFilter:self];
    for (NSInteger i = 0; i < section; i++) {
        [[_dataSource filter:self propertiesInSection:i] enumerateObjectsUsingBlock:^(id<SKUFilterPropertyProtocol>  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            if (obj.isSelectedProperty) {
                [selectedIndexPaths addObject:[NSIndexPath indexPathForItem:idx inSection:i]];
                *stop = YES;
            }
        }];;
    }
    _selectedIndexPaths = selectedIndexPaths;
}

/// 获取初始可选的所有indexPath
- (NSMutableSet<NSIndexPath *> *)getAllAvailableIndexPaths
{
    __block NSMutableSet<NSIndexPath *> *set = [NSMutableSet<NSIndexPath *> set];
    
    NSInteger section = [_dataSource numberOfSectionsForPropertiesInFilter:self];
    for (NSInteger i = 0; i < section; i++) {
        NSInteger row = [_dataSource filter:self propertiesInSection:i].count;
        for (NSInteger r = 0; r < row; r++) {
            [set addObject:[NSIndexPath indexPathForItem:r inSection:i]];
        }
    }
    _availableIndexPathsSet = set;
    _allAvailableIndexPaths = set.copy;
    return set;
}

/// 通过条件 获取可选sku信息
- (NSSet<SKUFilterCondition *> *)availableConditionsWithConditions:(NSArray<SKUConditionType> *)conditions
{
    NSMutableString *predString = @"".mutableCopy;
    for (int i = 0; i < conditions.count; i++) {
        [predString appendFormat:@"result.conditions CONTAINS '%@'",conditions[i]];
        if (i < conditions.count - 1) {
            [predString appendString:@" AND "];
        }
    }
    return [_filterConditions filteredSetUsingPredicate:[NSPredicate predicateWithFormat:predString.copy]];
}

/// 通过可选sku信息 获取可选索引
- (NSSet<NSIndexPath *> *)availableIndexPathsWithAvailableConditions:(NSSet<SKUFilterCondition *> *)availableConditions
{
    NSArray<NSArray<NSIndexPath *> *> *conditionIndexPathss = [availableConditions valueForKey:@"conditionIndexPaths"];
    NSMutableSet<NSIndexPath *> *set = [NSMutableSet<NSIndexPath *> set];
    for (NSArray<NSIndexPath *> *obj in conditionIndexPathss) {
        [set addObjectsFromArray:obj];
    }
    /// 去重
    return [NSSet setWithArray:set.allObjects];
}

/// 通过条件 获取可选索引
- (NSSet<NSIndexPath *> *)availableIndexPathsWithConditions:(NSArray<SKUConditionType> *)conditions
{
    NSMutableString *predString = @"".mutableCopy;
    for (int i = 0; i < conditions.count; i++) {
        [predString appendFormat:@"result.conditions CONTAINS '%@'",conditions[i]];
        if (i < conditions.count - 1) {
            [predString appendString:@" AND "];
        }
    }
    NSArray<NSArray<NSIndexPath *> *> *conditionIndexPathss = [[_filterConditions filteredSetUsingPredicate:[NSPredicate predicateWithFormat:predString.copy]] valueForKey:@"conditionIndexPaths"];
    NSMutableSet<NSIndexPath *> *set = [NSMutableSet<NSIndexPath *> set];
    for (NSArray<NSIndexPath *> *obj in conditionIndexPathss) {
        [set addObjectsFromArray:obj];
    }
    /// 去重
    return [NSSet setWithArray:set.allObjects];
}


/// 更新当前可用索引
- (void)updateAvailableIndexPaths
{
    if (_selectedIndexPaths.count == 0) {
        _availableIndexPathsSet = [_allAvailableIndexPaths mutableCopy];
        return;
    }
    
    __weak __typeof(&*self)weakSelf = self;
    __block NSMutableArray<SKUConditionType> *conditions = @[].mutableCopy;
    [_selectedIndexPaths enumerateObjectsUsingBlock:^(NSIndexPath * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        id<SKUFilterPropertyProtocol> property = [weakSelf getPropertyByIndexPath:obj];
        if (property) {
            [conditions addObject:property.propertyCondition];
        }
    }];
    
    _availableConditions = [self availableConditionsWithConditions:conditions.copy].mutableCopy;
    _availableIndexPathsSet = [self availableIndexPathsWithAvailableConditions:_availableConditions].mutableCopy;
}

/// 更新选中结果
- (void)updateResult
{
    if (_selectedIndexPaths.count != [_dataSource numberOfSectionsForPropertiesInFilter:self]) {
        _result = nil;
    }else{
        NSParameterAssert(_availableConditions.count == 1);
        _result = _availableConditions.allObjects.firstObject.result;
    }
}

@end

@interface SKUFilterCondition()
@property(nonatomic ,copy ,readwrite) NSArray<NSIndexPath *> *conditionIndexPaths;
@end
@implementation SKUFilterCondition
- (void)setProperties:(NSArray<SKUFilterProperty *> *)properties
{
    _properties = properties;
    __block NSMutableArray<NSIndexPath *> *array = @[].mutableCopy;
    [properties enumerateObjectsUsingBlock:^(SKUFilterProperty * _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
        [array addObject:obj.indexPath];
    }];
    _conditionIndexPaths = array.copy;
}
@end

@interface SKUFilterProperty()
@property(nonatomic ,copy ,readwrite) NSIndexPath *indexPath;
@property(nonatomic ,strong ,readwrite) id<SKUFilterPropertyProtocol> value;
@end

@implementation SKUFilterProperty
+ (instancetype)initWithValue:(id<SKUFilterPropertyProtocol>)value indexPath:(NSIndexPath *)indexPath
{
    SKUFilterProperty *p = [[self alloc] init];
    p.value = value;
    p.indexPath = indexPath;
    return p;
}
@end
