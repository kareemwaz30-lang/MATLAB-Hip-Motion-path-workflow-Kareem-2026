function [ x,y,z ] = RotateXYV(x,y,z,angleX,angleY,angleV)
%UNTITLED2 Summary of this function goes here
%   rotates a point x,y,z about the x axis by angleX. Then rotates about the
%   y axis by angleY and then rotates along the axis from the origin to the
%   new point position by angleV 
%   This is Layton's Orginal helper function, used for the hip motion path
%   script.

matX=[1,0,0;0,cos(angleX),sin(angleX);0,-sin(angleX),cos(angleX)];
matY=[cos(angleY),0,sin(angleY);0,1,0;-sin(angleY),0,cos(angleY)];
new=matY*matX*[x;y;z];
vector=[new(1),new(2),new(3)];
vector=vector/(norm(vector));
matZ=[cos(angleV)+(vector(1)^2)*(1-cos(angleV))                 ,vector(1)*vector(2)*(1-cos(angleV))-vector(3)*sin(angleV)  ,vector(1)*vector(3)*(1-cos(angleV))+vector(2)*sin(angleV); ...
    vector(2)*vector(1)*(1-cos(angleV))+vector(3)*sin(angleV)   ,cos(angleV)+(vector(2)^2)*(1-cos(angleV))                  ,vector(2)*vector(3)*(1-cos(angleV))-vector(1)*sin(angleV); ...
    vector(3)*vector(1)*(1-cos(angleV))-vector(2)*sin(angleV)   ,vector(3)*vector(2)*(1-cos(angleV))+vector(1)*sin(angleV)  ,cos(angleV)+(vector(3)^2)*(1-cos(angleV))];
new=matZ*new;
x=new(1,:);
y=new(2,:);
z=new(3,:);
end
