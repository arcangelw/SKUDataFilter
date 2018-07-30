//
//  SKUStandardListFilter.h
//  SKU Demo
//
//  Created by 吴哲 on 2018/7/30.
//  Copyright © 2018年 arcangelw. All rights reserved.
//  对所有筛选条件做快速遍历组合

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN
@class SKUDataFilter;
@class SKUFilterCondition;
@class SKUFilterProperty;

/// 筛选条件必须保证数据类型一致
typedef NSString * SKUConditionType;

@protocol SKUFilterConditionProtocol<NSObject>
@required

/// conditions sku数据对应筛选条件 数组 （数组长度必然和属性种类个数一致）
@property(nonatomic ,copy) NSArray<SKUConditionType> *conditions;
@end

@protocol SKUFilterPropertyProtocol<NSObject>
@required
/// conditions sku对应筛选条件 （与每个属性种类子类对应）
@property(nonatomic ,copy) SKUConditionType propertyCondition;

/// isSelectedProperty 选中状态 如果有保存状态的需求 初始化设置为YES 仅初始化的时候会设置
/// 界面刷新请使用 selectedIndexPaths判断
@property(nonatomic ,assign) BOOL isSelectedProperty;
@end

@protocol SKUDataFilterDataSource<NSObject>
@required

/// sku属性种类个数
- (NSInteger)numberOfSectionsForPropertiesInFilter:(SKUDataFilter *)filter;

/// 每个种类所有的子类属性
- (NSArray<id<SKUFilterPropertyProtocol>> *)filter:(SKUDataFilter *)filter propertiesInSection:(NSInteger)section;

/// 通过 condition 获取对应的子类属性
- (id<SKUFilterPropertyProtocol>)filter:(SKUDataFilter *)filter propertiesInSection:(NSInteger)section propertyCondition:(SKUConditionType)condition;

/// sku详细数据
- (NSSet<id<SKUFilterConditionProtocol>> *)conditionsInFilter:(SKUDataFilter *)filter;

@optional
/// 自定义筛选 可以在此处自定义筛选条件 过滤sku信息数据
- (NSSet<SKUFilterCondition *> *)customConditionsInFilter:(SKUDataFilter *)filter originalConditions:(NSSet<SKUFilterCondition *> *)originalConditions;

@end

@interface SKUDataFilter : NSObject

/// dataSource
@property(nonatomic ,weak) id<SKUDataFilterDataSource> dataSource;
/// 当前选中indexPath
@property(nonatomic ,copy ,readonly) NSArray<NSIndexPath *> *selectedIndexPaths;
/// 当前可以选择属性indexPath
@property(nonatomic ,copy ,readonly) NSSet<NSIndexPath *> *availableIndexPathsSet;

/// 还可以选择的数据
@property(nonatomic ,copy ,readonly) NSSet<SKUFilterCondition *> *availableConditions;
/// 最终筛选结果
@property(nonatomic ,strong ,nullable ,readonly) SKUFilterCondition *result;

- (instancetype)initWithDataSource:(id<SKUDataFilterDataSource>)dataSource;

/// 选中 调用
- (void)didSelectedPropertyWithIndexPath:(NSIndexPath *)indexPath;

/// 刷新计算数据
- (void)reloadData;

/// 当前section是否有选中
- (BOOL)hasSelectedIndexPathInSection:(NSInteger)section;

@end

/// 存储单个sku信息筛选条件
@interface SKUFilterCondition : NSObject
/// properties 存储每个sku对应的子类属性
@property(nonatomic ,copy) NSArray<SKUFilterProperty *> *properties;
/// conditionIndexPaths 对应子类属性索引数组
@property(nonatomic ,copy ,readonly) NSArray<NSIndexPath *> *conditionIndexPaths;
/// result sku详细信息
@property(nonatomic ,strong) id<SKUFilterConditionProtocol> result;

@end

/// 子类信息及索引存储
@interface SKUFilterProperty : NSObject
/// indexPath 子类对应索引
@property(nonatomic ,copy ,readonly) NSIndexPath *indexPath;
/// value 对应子类索引信息
@property(nonatomic ,strong ,readonly) id<SKUFilterPropertyProtocol> value;

+ (instancetype)initWithValue:(id<SKUFilterPropertyProtocol>)value indexPath:(NSIndexPath *)indexPath;
@end
NS_ASSUME_NONNULL_END
