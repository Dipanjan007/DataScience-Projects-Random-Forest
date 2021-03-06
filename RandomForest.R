rm(list = ls(all = T))

# Load the required libraries
library(DMwR)
# This library has some function we use quite often. such as, KNN and Cetnral Imputation, regr.eval(),SMOTE, manyNAs(), 
library(randomForest)
# This library has some specific calls for Random Forest Algorithm - The model itself, importance of variables,
library(caret)
# Preprocess functions, nearzerovars etc.

# Read the data into R
data = read.table('hepatitis.txt', header=F, dec='.',
                  col.names=c('target','age','gender','steroid',
                              'antivirals','fatigue','malaise',
                              'anorexia','liverBig','liverFirm',
                              'spleen','spiders','ascites',
                              'varices','bili','alk','sgot',
                              'albu','protime','histology'), 
                  na.strings=c('?'), sep=',')

# Understand the data 
str(data)
summary(data)

table(data$target)
str(data$target) # 1: Die; 2: Live 

# Convert 1s and 2s into 1s and 0s 
data$target= ifelse(data$target==1, 1, 0 ) # 1: Die(+ve); 0: Live (-ve)

# The numerical variables are: age, bili, alk, sgot, albu and protime
# The categorical variables are: the remaining 14 variables

num_Attr = c("age", "bili", "alk", "sgot", "albu", "protime")
cat_Attr = setdiff(names(data), num_Attr)

# Seperate numerical and categorical variables and convert them into appropriate type

cat_Data = data.frame(sapply(data[,cat_Attr], as.factor))
num_Data = data.frame(sapply(data[,num_Attr], as.numeric))
data = cbind(num_Data, cat_Data)
head(data,10)
rm(num_Attr, cat_Attr)
rm(cat_Data, num_Data)

# Split dataset into train and test

set.seed(9)

train_RowIDs = sample(1:nrow(data), nrow(data)*0.7)
train_Data = data[train_RowIDs,]
test_Data = data[-train_RowIDs,]
rm(train_RowIDs)

# Check how records are split with respect to target attribute.
table(data$target)
table(train_Data$target)
table(test_Data$target)
rm(data)

# As part of Pre-processing, Imputation and scaling are done after train-evaluation/test split.
# Check to see if missing values in data
sum(is.na(train_Data))
sum(is.na(test_Data))

#Imputing missing values using KNN
train_Data <- knnImputation(data = train_Data, k = 5)
sum(is.na(train_Data))
test_Data <- knnImputation(data = test_Data, k = 5, distData = train_Data)
sum(is.na(test_Data))

# Model Building -

set.seed(123)

# Build the classification model using randomForest
model = randomForest(target ~ ., data=train_Data, 
                     keep.forest=TRUE, ntree=100) 

# Print and understand the model
print(model)


#No. of variables tried at each split = floor(sqrt(ncol(train_Data) - 1))

#Out-of-Bag is equivalent to validation or test data. In random forests, there is no need for a separate test set to validate 
#result. 
#It is estimated internally, during the run, as follows: As the forest is built on training data , each tree is tested on the 
#1/3rd of the samples (36.8%) not used in building that tree (similar to validation data set). This is the out of bag error 
#estimate - an internal error estimate of a random forest as it is being constructed.

# Important attributes
model$importance         #this Gini Gain which is inversely proportinal Gini Index
round(importance(model), 2)   

# Extract and store important variables obtained from the random forest model
rf_Imp_Attr = data.frame(model$importance)
rf_Imp_Attr = data.frame(row.names(rf_Imp_Attr),rf_Imp_Attr[,1])
colnames(rf_Imp_Attr) = c('Attributes', 'Importance')
rf_Imp_Attr = rf_Imp_Attr[order(rf_Imp_Attr$Importance, decreasing = TRUE),]

# plot (directly prints the important attributes) 
varImpPlot(model)

# Predict on Train data 
pred_Train = predict(model, 
                     train_Data[,setdiff(names(train_Data), "target")],
                     type="response", 
                     norm.votes=TRUE)

head(pred_Train, 10)

# Build confusion matrix and find accuracy   
cm_Train = table("actual"= train_Data$target, "predicted" = pred_Train);
accu_Train= sum(diag(cm_Train))/sum(cm_Train)
rm(pred_Train, cm_Train)

# Predicton Test Data
pred_Test = predict(model, test_Data[,setdiff(names(test_Data),
                                              "target")],
                    type="response", 
                    norm.votes=TRUE)

# Build confusion matrix and find accuracy   
cm_Test = table("actual"=test_Data$target, "predicted"=pred_Test);
accu_Test= sum(diag(cm_Test))/sum(cm_Test)
rm(pred_Test, cm_Test)

accu_Train
accu_Test

# Build randorm forest using top 11 important attributes. 
top_Imp_Attr = as.character(rf_Imp_Attr$Attributes[1:10])


set.seed(15)

# Build the classification model using randomForest
model_Imp = randomForest(target~.,
                         data=train_Data[,c(top_Imp_Attr,"target")], 
                         keep.forest=TRUE,ntree=100) 

# Print and understand the model
print(model_Imp)

# Important attributes
model_Imp$importance  

# Predict on Train data 
pred_Train = predict(model_Imp, train_Data[,top_Imp_Attr],
                     type="response", norm.votes=TRUE)


# Build confusion matrix and find accuracy   
cm_Train = table("actual" = train_Data$target, 
                 "predicted" = pred_Train);
accu_Train_Imp = sum(diag(cm_Train))/sum(cm_Train)
rm(pred_Train, cm_Train)

# Predicton Test Data
pred_Test = predict(model_Imp, test_Data[,top_Imp_Attr],
                    type="response", norm.votes=TRUE)

# Build confusion matrix and find accuracy   
cm_Test = table("actual" = test_Data$target, 
                "predicted" = pred_Test);
accu_Test_Imp = sum(diag(cm_Test))/sum(cm_Test)
rm(pred_Test, cm_Test)

accu_Train
accu_Test
accu_Train_Imp
accu_Test_Imp


#Select mtry value with minimum out of bag(OOB) error.
mtry <- tuneRF(train_Data[-7],train_Data$target, ntreeTry=100,
               stepFactor=1.5,improve=0.01, trace=TRUE, plot=TRUE)
print(mtry)      #mtry = 6 is giving lest oob error
best.m <- mtry[mtry[, 2] == min(mtry[, 2]), 1]
print(mtry)
print(best.m)


#Parameters in tuneRF function
#The stepFactor specifies at each iteration, mtry is inflated (or deflated) by this value
#The improve specifies the (relative) improvement in OOB error must be by this much for the search to continue
#The trace specifies whether to print the progress of the search
#The plot specifies whether to plot the OOB error as function of mtry


#Build Model with best mtry again - 
set.seed(71)
rf <- randomForest(target~.,data=train_Data, mtry=best.m, importance=TRUE,ntree=100)
print(rf)

#Evaluate variable importance
importance(rf)

# Important attributes
model$importance  
round(importance(model), 2)   

# Extract and store important variables obtained from the random forest model
rf_Imp_Attr = data.frame(model$importance)
rf_Imp_Attr = data.frame(row.names(rf_Imp_Attr),rf_Imp_Attr[,1])
colnames(rf_Imp_Attr) = c('Attributes', 'Importance')
rf_Imp_Attr = rf_Imp_Attr[order(rf_Imp_Attr$Importance, decreasing = TRUE),]

# Predict on Train data 
pred_Train = predict(model, 
                     train_Data[,setdiff(names(train_Data), "target")],
                     type="response", 
                     norm.votes=TRUE)

# Build confusion matrix and find accuracy   
cm_Train = table("actual"= train_Data$target, "predicted" = pred_Train);
accu_Train = sum(diag(cm_Train))/sum(cm_Train)
rm(pred_Train, cm_Train)

# Predicton Test Data
pred_Test = predict(model, test_Data[,setdiff(names(test_Data),
                                              "target")],
                    type="response", 
                    norm.votes=TRUE)

# Build confusion matrix and find accuracy   
cm_Test = table("actual"=test_Data$target, "predicted"=pred_Test);
accu_Test= sum(diag(cm_Test))/sum(cm_Test)
rm(cm_Test)

accu_Train
accu_Test

