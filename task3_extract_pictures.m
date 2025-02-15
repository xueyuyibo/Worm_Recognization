clear all;clc;close all;
total_image = 7;
for image_num=1:total_image
    for color_num=1:3
        for threshold=0.1:0.01:0.2 %0.15
            fprintf(['image_num=',num2str(image_num),'\n']);
            fprintf(['color_num=',num2str(color_num),'\n']);
            fprintf(['threshold_percent=',num2str((threshold-0.1)/0.1),'\n']);
            extract_worm(image_num,color_num,threshold);
        end
    end
end

function extract_worm(image_num,color_num,threshold)
    global I cc wormdata;
    folder_name = {'pi','cfp','fitc'};
    if ~exist(['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num)],'dir')==1
        mkdir(['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num)]);
    end
    A = imread(['Original_images/new/batchA',num2str(image_num),'/',folder_name{color_num},num2str(image_num),'.tif']);
    I = rgb2gray(A);
    I = LinearEnhance(I,20,80,50,230);

    % eliminate bright areas in background(see results in docx):
    se = strel('disk',20);  % build disk-shape circle whose r is 20
    background = imopen(I,se); % open images(erosion with element inside the bright areas, if element contains then preserve)
    clear se;
    I = I - background;
    clear background;
    I = LinearEnhance(I,20,80,50,230);
    I = imbinarize(I,threshold);
    I = bwareaopen(I,500,4); % remove all connected areas that have fewer than 300 pixels, 8 is the connectivity

    cc = bwconncomp(I,8); % get a struct contains Connectivity&ImageSize&NumObjects&PixelIdxList of connected areas
    idx = cc.NumObjects; % number of connected areas
    wormdata = regionprops(cc,'basic'); % get Area&BoundingBox&Centroid of each area
    [max_area,~] = max([wormdata.Area]);
    [min_area,~] = min([wormdata.Area]);
    figure('units', 'pixels', 'innerposition', [0 0 800 1400]);
    sample_interval = 10;
    i = 1;
%     j = 1;
    for k=1:idx
        worm = localize_worm(k);
        worm_full = full_worm(k);
        cor_boundary = get_boundary(worm);
        cor_boundary_full = get_boundary(worm_full);
        [boundary_num,~] = size(cor_boundary);
        edge_sample = edge_sample_select(cor_boundary,sample_interval);
        edge_sample_full = edge_sample_select(cor_boundary_full,sample_interval);
%         plot(edge_sample(:,2),edge_sample(:,1),'xm');

        mid_points = get_mid_points(worm,edge_sample);
        mid_points_full = get_mid_points(worm_full,edge_sample_full);
%         plot(mid_points(:,2),mid_points(:,1),'.k'); % link the original mid_points
        mid_points = points_simplize(mid_points,5);mid_points = points_simplize(mid_points,5);mid_points = points_simplize(mid_points,5);
        mid_points_full = points_simplize(mid_points_full,5);mid_points_full = points_simplize(mid_points_full,5);mid_points_full = points_simplize(mid_points_full,5);
%         plot(mid_points(:,2),mid_points(:,1),'ob');
        [line_points,points_unused] = form_line(mid_points,25);
        [line_points_full,~] = form_line(mid_points_full,25);
        clear mid_points_full;
        [num_unused,~] = size(points_unused);
        if num_unused == 0 && wormdata(k).Area/boundary_num>=4
            clear boundary_num;
            imshow(worm,'InitialMagnification','fit');title(i);
            hold on;
            plot(edge_sample(:,2),edge_sample(:,1),'xm');
            plot(mid_points(:,2),mid_points(:,1),'ob');
            plot(points_unused(:,2),points_unused(:,1),'*r');
            show_line(line_points);
            save (['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num),'/data_',num2str(i),'.mat']);
            saveas(gcf,['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num),'/line_',num2str(i),'.png']);
            a = wormdata(k).BoundingBox(1)+0.5;
            b = wormdata(k).BoundingBox(2)+0.5;
            c = wormdata(k).BoundingBox(3);
            d = wormdata(k).BoundingBox(4);
            [size_a,size_b,~] = size(A);
            worm_RGB = A(b:b+d-1,a:a+c-1,:);
            worm_blank = A;
            for m=1:size_a
                for n=1:size_b
                    for l=1:3
                        worm_blank(m,n,l) = 0;
                    end
                end
            end
            worm_RGB = [worm_blank(1:5,1:(c+10),:);worm_blank(1:d,1:5,:),worm_RGB,worm_blank(1:d,1:5,:);worm_blank(1:5,1:(c+10),:)];
            imshow(worm_RGB,'InitialMagnification','fit');title(i);
            saveas(gcf,['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num),'/worm_',num2str(i),'.png']);
            clear a b c d m n l size_a size_b worm_blank;
            i = i+1;
        end
    end
    total_worms = i-1;
    save (['output/threshold_',num2str(threshold),'/image_',num2str(image_num),'/color_',num2str(color_num),'/data_image.mat']);
    close all;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function points = points_simplize(points_sample,dis)
% for points in the neighbor, find the mean of them, and replace the points with the mean
points = points_sample;
[num_size,~] = size(points);
i = 1;
while i<=num_size
    points_group = [0 0];
%     plot(points(:,2),points(:,1),'ow');
%     plot(points(i,2),points(i,1),'oc');
    for j=1:num_size % for every point, find the neighbor points
        if norm(points(i,:)-points(j,:)) <= dis % the "neighbor" is defined by the distance of dis
            points_group = [points_group;points(j,:)]; % list the neighbor points group
        end
    end
    [num_group,~] = size(points_group);
    if num_group > 1 % if there exists a neighbor point for every point i
        points_group = points_group(2:end,:);
%         plot(points_group(:,2),points_group(:,1),'ob');
        [num_group,~] = size(points_group);
        for j=1:num_group % for every point in the group, find the same point in the original point list and remove it
            k = 1;
            while k<=num_size
                if points(k,:)==points_group(j,:)
                    if k==1
                        points = points(2:end,:);
                    elseif k==num_size
                        points = points(1:num_size-1,:);
                    else
                        points = [points(1:k-1,:);points(k+1:end,:)];
                    end
%                     if k <= i % move forward the index, and if i<0, set i=0
%                         i = i-1;
%                     end
                end
                [num_size,~] = size(points);
                k = k+1;
            end
        end
        points = [points;fix(mean(points_group,1))]; % plug the mean at the end
%         plot(points(num_size+1,2),points(num_size+1,1),'or');
%         plot(points_group(:,2),points_group(:,1),'ow');
    end
    [num_size,~] = size(points);
    i = i+1;
%     plot(points(:,2),points(:,1),'ob');
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function points = get_mid_points(worm,edge_sample)
% find list of mid_points
% 1st for loop: for each point
% 2nd for loop: for every points group
% why? see in "judge_group"
[num,~] = size(edge_sample);
points = [0 0];
group_num = 3;
for i=1:num
    goal_dis = 10000;
%     plot(edge_sample(i,2),edge_sample(i,1),'or'); %%%%
    if i==1
        edge_sample3 = edge_sample(2:num,:);
    elseif i==num
        edge_sample3 = edge_sample(1:num-1,:);
    else
        edge_sample3 = [edge_sample(i+1:num,:);edge_sample(1:i-1,:)]; % range of goal_points(num-1)
    end
    for j=1:num-group_num % each group has 3 points
%         plot(edge_sample3(j:j+group_num-1,2),edge_sample3(j:j+group_num-1,1),'*r'); %%%%
        [judge,n,dis] = judge_group(worm,edge_sample3(j:j+group_num-1,:),edge_sample(i,:));
        if judge == 1
            if goal_dis >= dis
                goal_point = edge_sample3(j+n-1,:); % record goal_point
                goal_dis = dis; % record goal_distance
%                 goal_group_num = j; %%%%
%                 goal_num = j+n-1; %%%%
            end
        end
%         plot(edge_sample3(j:j+group_num-1,2),edge_sample3(j:j+group_num-1,1),'*w'); %%%%
%         plot(edge_sample3(j:j+group_num-1,2),edge_sample3(j:j+group_num-1,1),'xm'); %%%%
    end
    if goal_dis < 35 % if there exist a goal point for the point now, and the dis should not be larger than twice the width of the worm
        mid_point = round((goal_point+edge_sample(i,:))/2);
%         now_point = edge_sample(i,:); %%%%
%         goal_group = edge_sample3(goal_group_num:goal_group_num+group_num-1,:);%%%%
%         plot(goal_point(2),goal_point(1),'*r');%%%%
%         plot(mid_point(2),mid_point(1),'ob');%%%%
        points = [points;mid_point];
%         plot(goal_point(2),goal_point(1),'*w');%%%%
%         plot(goal_point(2),goal_point(1),'xm');%%%%
%         plot(mid_point(2),mid_point(1),'ow');%%%%
%         plot(mid_point(2),mid_point(1),'.k');%%%%
    end
%     plot(edge_sample(i,2),edge_sample(i,1),'ow');%%%%
end
points = points(2:end,:);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [judge,n,k] = judge_group(worm,goal_group,now_point)
% for each sample, to select points to the opposite side, we can let the
% goal point lies in a group where:
% 1.the local min of norm is in the group, not on the side
% 2.the goal_point in the group satisfies "most of the line between two points are in the area"
[num,~] = size(goal_group);
k = 10000;
for i=1:num % judge the 1st principle
    if norm(now_point-goal_group(i,:)) < k
        k = norm(now_point-goal_group(i,:));
        n = i;
    end
end
if judge_twopoints(worm,now_point,goal_group(n,:)) == 1 && (n < num && n > 1) % judge the 2nd principle
    judge = 1;
else
    judge = 0;
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function judge = judge_twopoints(worm,p1,p2)
% judge if most of the line between two points are in the area
m = 0; % two points are not the same point
if p2(1) == p1(1) 
    if p2(2) ~= p1(2)
        cor_line = [p1(1)*ones(1,abs(p2(2)-p1(2)+(p2(2)-p1(2))/abs(p2(2)-p1(2))));p1(2):(p2(2)-p1(2))/abs(p2(2)-p1(2)):p2(2)];
    else
        m = 1; % two points are the same point
    end
else
    k = (p2(2)-p1(2))/(p2(1)-p1(1)); % calculate the slope
    if k ~= 0
        if abs(k)>=1
            cor_line = [p1(1):(p2(1)-p1(1))/abs(p2(1)-p1(1)):p2(1);fix(p1(2):k*(p2(1)-p1(1))/abs(p2(1)-p1(1)):p2(2))]; % cor of points in the line
        else
            k = 1/k; % in this case, the line will loss some points if this case is not divided
            cor_line = [fix(p1(1):k*(p2(2)-p1(2))/abs(p2(2)-p1(2)):p2(1));p1(2):(p2(2)-p1(2))/abs(p2(2)-p1(2)):p2(2)]; % cor of points in the line
        end
    else
        cor_line = [p1(1):(p2(1)-p1(1))/abs(p2(1)-p1(1)):p2(1);p1(2)*ones(1,abs(p2(1)-p1(1)+(p2(1)-p1(1))/abs(p2(1)-p1(1))))];
    end
end
if m == 0
    [~,num] = size(cor_line);
    s = 0;
    for i=1:num
        if worm(cor_line(1,i),cor_line(2,i)) == true % if this point is in the area
            s = s+1;
        end
    end
    mid_point = round((p1+p2)/2);
%     if ((s/num)>=0.5) && (worm(mid_point(1),mid_point(2))==true) % if most points in the line are in the area and the mid point is in the area
    if ((s/num)>=0.7)
        judge = 1;
    else
        judge = 0;
    end
else
    judge = 0;
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function worm = localize_worm(num)
% get localized worm img
global cc;
Bounding = get_boundingbox(num);
worm = false(Bounding(2,2)-Bounding(1,2)+1,Bounding(2,1)-Bounding(1,1)+1);
cor = get_coordinate(cc.PixelIdxList{num})-Bounding(1,:)+[1,1]; % get cor correlating to worm
vector = (cor(:,1)-1)*(Bounding(2,2)-Bounding(1,2)+1)+cor(:,2); % get vector correlating to worm
worm(vector) = true;
% plus a "frame" of width 5 to worm:
worm = [false(5,(Bounding(2,1)-Bounding(1,1)+1)+10);false((Bounding(2,2)-Bounding(1,2)+1),5),worm,false((Bounding(2,2)-Bounding(1,2)+1),5);false(5,(Bounding(2,1)-Bounding(1,1)+1)+10)];
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function worm_full = full_worm(num)
% get worm full img
global cc;
worm_full = false(cc.ImageSize);
worm_full(cc.PixelIdxList{num}) = true;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function Bounding = get_boundingbox(num)
% get boundary:we can use wormdata(i).BoundingBox,but it's a 1*4vector 
% [x y x_width y-width], where x&y are cor of upper-left-corner
% we do not use this because: 
% 1st.x&y are not int(is x or y minus 0.5); 
% 2nd.we cannot get all boundaries, we just get widths
global cc;
a = min(get_coordinate(cc.PixelIdxList{num}));
b = max(get_coordinate(cc.PixelIdxList{num}));
Bounding = [a;b];
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cor_area = get_coordinate(vector)
% get cor from vector
global I;
[r,~] = size(I);
x = mod(vector,r)+(mod(vector,1440)==0)*r;
y = (vector-x)/r+1;
cor_area = [x,y];
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function cor_boundary = get_boundary(worm)
B = bwboundaries(worm); % get a (p*1)cell array of boundary points
[numbcell,~] = size(B);
cor_boundary = [0 0];
for i=1:numbcell
    [numbarray,~] = size(B{i});
    if numbarray>20 % if the number of boundary points are larger than 20, which means it's a big inner area
        cor_boundary = [cor_boundary;B{i}]; % link different boundaries together
    end
end
cor_boundary = cor_boundary(2:end,:);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function edge_sample = edge_sample_select(cor_boundary,num)
% select sample points in boundary
edge_sample = cor_boundary(1:num:end,:);
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function [line_points,points_unused] = form_line(points,dis)
% start with the first point, find the closest point in the neighbor(norm<dis), and give the rest point set "points_unused"
line_points = points(1,:); % from the first point
points_unused = points; % initialize points_unused
[num,~] = size(points);
points2 = points;
points2(1,:) = [-1000 -1000];
% plot(line_points(2),line_points(1),'*r');
i = 1; % find the "head"
while i>0 % for every point i in line_points, find the closest point in the neighbor of dis
    distance = dis;
    n = 0;flag = 1;
    for j=1:num
        if norm(line_points(i,:)-points2(j,:))<distance
            distance = norm(line_points(i,:)-points2(j,:));
            n = j;flag = 0;
        end
    end
    if flag==0
%         plot(points2(n,2),points2(n,1),'*r');
        line_points = [line_points;points2(n,:)];
        points2(n,:) = [-1000 -1000];
        i = i+1;
    else
        break;
    end
end
% plot(line_points(:,2),line_points(:,1),'*w');

line_points = line_points(i,:); % now we have a "head", then start with it again
points2 = points;
for i=1:num
    if line_points==points2(i,:)
        points2(i,:) = [-1000 -1000];
    end
end
% plot(line_points(2),line_points(1),'*r');
i = 1;
while i>0 % for every point i in line_points, find the closest point in the neighbor of dis
    distance = dis;
    n = 0;flag = 1;
    for j=1:num
        if norm(line_points(i,:)-points2(j,:))<distance
            distance = norm(line_points(i,:)-points2(j,:));
            n = j;flag = 0;
        end
    end
    if flag==0
%         plot(points2(n,2),points2(n,1),'*r');
        line_points = [line_points;points2(n,:)];
        points2(n,:) = [-1000 -1000];
        i = i+1;
    else
        break;
    end
end

[num_line,~] = size(line_points);
for i=1:num_line % remove the line_points from points_unused
    j = 1;
    while j<=num
        if line_points(i,:)==points_unused(j,:)
            if j==1
                points_unused = points_unused(2:end,:);
            elseif j==num
                points_unused = points_unused(1:j-1,:);
            else
                points_unused = [points_unused(1:j-1,:);points_unused(j+1:end,:)];
            end
            [num,~] = size(points_unused);
            j = j-1;
        end
        j = j+1;
    end
end
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function show_line(line_points)
% show line parts in random color
[num,~] = size(line_points);
hold on;
for i=1:num-1
    plot([line_points(i,2),line_points(i+1,2)],[line_points(i,1),line_points(i+1,1)],'Color',rand(1,3),'LineWidth',2);
end
hold off;
end
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
function dst_img = LinearEnhance(ori_img,fa,fb,ga,gb)
[height,width] = size(ori_img);  
dst_img = uint8(zeros(height,width));  
ori_img = double(ori_img);
m = min(min(ori_img));
k1 = ga/fa;   
k2 = (gb-ga)/(fb-fa);  
k3 = (255-gb)/(255-fb);  
for i=1:height  
    for j=1:width  
            mid_img = ori_img(i,j)-m;
            if mid_img <= fa  
                dst_img(i,j) = k1*mid_img;  
            elseif fa < mid_img && mid_img <= fb  
                dst_img(i,j) = k2*(mid_img-fa)+ ga;  
            else  
                dst_img(i,j) = k3*(mid_img-fb)+ gb;  
            end  
    end  
end  
dst_img = uint8(dst_img);
end
