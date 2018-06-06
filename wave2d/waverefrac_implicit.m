function [W]=waverefrac_implicit(W0);
%% Function to compute wave refraction on a regular grid
%%
%% Default values
W.eps=1e-6;
W.crit=0.001;
W.ntheta=36;
W.thetamin=-180;
W.thetamax=0;
W.dtheta=(W.thetamax-W.thetamin)/W.ntheta;
W.theta=W.thetamin+.5*W.dtheta+[0:W.ntheta-1]*W.dtheta;
W.theta=W.theta*pi/180;
W.dtheta=W.dtheta*pi/180;
W.dt=1000
W.niter=50;
W.g=9.81;
W.rho=1025;
W.h0=10;
W.hmin=.1;
W.H0=1;
W.m=20;
W.gamma=0.75;
W.gammax=.6;
W.alfa=1;
W.gridfile=''
W.wavefile='';
W.depfile='';
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%% SET INPUT DATA
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
fieldnms=fields(W0);
for ii=1:length(fieldnms)
    W.(fieldnms{ii}) = W0.(fieldnms{ii});
end

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


grid=wlgrid('read',W.gridfile);
x=grid.X;
y=grid.Y;
xg=x;
yg=y;
nx=size(x,1)-1;
ny=size(x,2)-1;
dx=hypot(x(2,1)-x(1,1),y(2,1)-y(1,1));
dy=hypot(x(1,2)-x(1,1),y(1,2)-y(1,1));
alfagrid=atan2(y(2,1)-y(1,1),x(2,1)-x(1,1));
%local grid
for j=1:size(x,2)
    for i=1:size(x,1)
        x(i,j)=(i-1)*dx;
        y(i,j)=(j-1)*dy;
    end
end
W.theta=W.theta-alfagrid;
zb=-wldep('read',W.depfile,grid);
zb=zb(1:end-1,1:end-1);
figure;
pcolor(xg,yg,zb);
shading flat;
colormap jet;
axis equal;
colorbar
idir=0;
for dirnaut=60;%-90:20:90
    dir0=mod(270-dirnaut,360);
    idir=idir+1
    iT=0;
    for T=10;%4:2:10
        iT=iT+1;
        omega=2*pi/T;
        fp=1/T;
        thetamean=dir0*pi/180;
        thetamean=thetamean-alfagrid;
        it=zeros(size(x));
        h=max(-zb,W.hmin);
        dhdx=zeros(size(h));
        dhdx(2:end-1,:)=(h(3:end,:)-h(1:end-2,:))/(2*dx);
        dhdx(1,:)=(h(2,:)-h(1,:))/dx;
        dhdx(end,:)=(h(end,:)-h(end-1,:))/dx;
        dhdy=zeros(size(dhdx));
        dhdy(:,2:end-1)=(h(:,3:end)-h(:,1:end-2))/(2*dx);
        dhdy(:,1)=(h(:,2)-h(:,1))/dx;
        dhdy(:,end)=(h(:,end)-h(:,end-1))/dx;
        k=disper(omega,h,W.g);
        c=omega./k;
        kh=k.*h;
        tkh=tanh(kh);
        cg=W.g/2./omega.*(tkh+kh.*(1.-tkh.*tkh));
        
        H=min(W.H0, W.gamma*h);
        H(2:end,:)=0;
        %DoverE=2*W.alfa./T.*(1-exp(-(H/W.gamma./h).^n));
        E=1/8*W.rho*W.g*H.^2;%zeros(size(x));
        psi=zeros(size(x));
        coef=zeros(size(x));
        Hmax=0.88./k.*tanh(W.gamma*k.*h/0.88);
        Emax=1/8*W.rho*W.g*Hmax.^2;
        ee=squeeze(zeros([size(x),W.ntheta]));
        eeprop=zeros(size(ee));
        eeref=zeros(size(ee));
        eeold=zeros(size(ee));
        A=zeros(size(ee));
        B=zeros(size(ee));
        C=zeros(size(ee));
        R=zeros(size(ee));
        %angdif=atan2(sin(W.theta)-sin(thetamean),cos(W.theta)-cos(thetamean));
        angdif=W.theta-thetamean;
        angdif(angdif<-pi)=angdif(angdif<-pi)+2*pi;
        dist=(cos(angdif)).^W.m;
        dist(abs(angdif)>pi/2)=0;
        dir=zeros(size(x));
        for j=1:size(x,2)
            for i=1;%:size(x,1)
                ee(i,j,:)=dist/sum(dist)*E(i,j)/W.dtheta;
                dir(i,j)=sum(squeeze(ee(i,j,:)).*W.theta')/sum(ee(i,j,:));
            end
        end
        
        sinth=sin(W.theta);
        costh=cos(W.theta);
        tic
        sigm=omega;
        for itheta=1:W.ntheta
            ctheta(:,:,itheta)= sigm./sinh(2.*k.*h).*(dhdx*sinth(itheta)-dhdy*costh(itheta));
        end
        ds=dx./cos(W.theta);
        dy_bt=-dx*tan(W.theta);
        j_bt=dy_bt/dy;
        j_bt1=floor(dy_bt/dy);
        j_bt2=j_bt1+1;
        w2=(j_bt-j_bt1)./(j_bt2-j_bt1);
        w1=1-w2;
        
        for i=2:size(x,1);
            for j=1:size(x,2);
                Hold=1000;
                for itheta=1:W.ntheta
                    j1=max(min(j+j_bt1(itheta),ny+1),1);
                    j2=max(min(j+j_bt2(itheta),ny+1),1);
                    eeprev(itheta)=w1(itheta)*ee(i-1,j1,itheta)+w2(itheta)*ee(i-1,j2,itheta);
                    cgprev(itheta)=w1(itheta)*cg(i-1,j1)       +w2(itheta)*cg(i-1,j2);
                end
                for iter=1:W.niter
                    eeold(i,j,:)=ee(i,j,:);
                    
                    if h(i,j)>1.1*W.hmin
                        psi(i,j)=Emax(i,j)/max(E(i,j),W.eps);
                        coef(i,j)=2*W.alfa*fp*exp(-psi(i,j));
                        D(i,j)=coef(i,j).*(Emax(i,j)+E(i,j));
                        DoverE(i,j)=coef(i,j).*(psi(i,j)+1);
                        
                        for itheta=2:W.ntheta-1
                            A(i,j,itheta)=-ctheta(i,j,itheta-1)/2/W.dtheta;
                            B(i,j,itheta)=1/W.dt+cg(i,j)/ds(itheta)+DoverE(i,j);
                            C(i,j,itheta)=ctheta(i,j,itheta+1)/2/W.dtheta;
                            R(i,j,itheta)=ee(i,j,itheta)/W.dt+cgprev(itheta)*eeprev(itheta)/ds(itheta);
                        end
                        if ctheta(i,j,1)<0;
                            A(i,j,1)=0;
                            B(i,j,1)=1/W.dt-ctheta(i,j,1)/W.dtheta+cg(i,j)/ds(1)+DoverE(i,j);
                            C(i,j,1)=ctheta(i,j,2)/W.dtheta;
                            R(i,j,1)=ee(i,j,1)/W.dt+cgprev(1)*eeprev(1)/ds(1);
                        else
                            A(i,j,1)=0;
                            B(i,j,1)=1/W.dt;
                            C(i,j,1)=0;
                            R(i,j,1)=0;
                        end
                        if ctheta(i,j,W.ntheta)>0
                            A(i,j,W.ntheta)=-ctheta(i,j,W.ntheta-1)/W.dtheta;
                            B(i,j,W.ntheta)=1/W.dt+ctheta(i,j,W.ntheta)/W.dtheta+cg(i,j)/ds(W.ntheta)+DoverE(i,j);
                            C(i,j,W.ntheta)=0;
                            R(i,j,W.ntheta)=ee(i,j,W.ntheta)/W.dt+cgprev(W.ntheta)*eeprev(W.ntheta)/ds(W.ntheta);
                        else
                            A(i,j,W.ntheta)=0;
                            B(i,j,W.ntheta)=1/W.dt;
                            C(i,j,W.ntheta)=0;
                            R(i,j,W.ntheta)=0;
                        end
                        ee(i,j,:)=tridiag(A(i,j,:),B(i,j,:),C(i,j,:),R(i,j,:),W.ntheta);
                        ee(i,j,:)=max(ee(i,j,:),0);
                    else
                        ee(i,j,:)=0;
                    end
                    %         figure(2)
                    %         plot(W.theta,ee(i,:));title(num2str(i));pause(0.2)
                    dee(i,j,:)=ee(i,j,:)-eeold(i,j,:);
                    ee(i,j,:)=max(ee(i,j,:),0);
                    E(i,j)=sum(ee(i,j,:))*W.dtheta;
                    dir(i,j)=sum(squeeze(ee(i,j,:)).*W.theta')/sum(ee(i,j,:));
                    
                    H(i,j)=sqrt(8*E(i,j)/W.rho/W.g);
                    %     reducfac=1./(min(H,W.gammax*h).^2);
                    %     for i=1:length(x)
                    %         ee(i,:)=ee(i,:)*reducfac(i);
                    %     end
                    %DoverE(i,j)=(1-fac)*DoverE(i,j)+fac*2*W.alfa/T*(1-exp(-(H(i,j)/W.gamma./h(i,j)).^n));
                    %             pcolor(x,y,H);shading flat;axis equal;drawnow
                    diff=max(abs(dee(i,j,:)));
                    if diff<W.crit
                        it(i,j)=iter;
                        break
                        disp([num2str(i),'diff',num2str(diff)])
                    end
                end
            end
        end
        toc
        dir=dir+alfagrid;
        figure;
        pcolor(xg,yg,H);shading flat;colorbar
        colormap jet
        hold on;
        contour(xg,yg,zb,[-10:1],'k')
        caxis([0 max(max(H))])
        scale=.8*dx/H(1,1);
        vecx=[xg(:),xg(:)+scale*H(:).*cos(dir(:))];
        vecy=[yg(:),yg(:)+scale*H(:).*sin(dir(:))];
        plot(vecx',vecy','k',vecx(:,1),vecy(:,1),'.k','linewidth',1)
        axis equal
        
        fname=[W.wavefile,num2str(dir0),'Tp',num2str(T),'.jpg'];
        print('-djpeg',fname);
        Hg(:,:,idir,iT)=H;
        dirg(:,:,idir,iT)=mod(270-dir*180/pi,360);
        
        dirtab(idir)=dirnaut;
        Tptab(iT)=T;
    end
end
save(W.wavefile,'xg','yg','zb','Hg','dirg','dirtab','Tptab');
% subplot(411)

% plot(x,h,x,H,'linewidth',2);colorbar
% set(gca,'ylim',[0 3])
% title(['H, iter = ',num2str(iter)])
% hold on
% subplot(412)
% pcolor(x,W.theta*180/pi,ee');shading flat;caxis([-6000 6000]);colorbar
% title('ee')
% subplot(413)
% pcolor(x,W.theta*180/pi,dee');shading flat;%caxis([-6000 6000]);
% title('dee');colorbar
% subplot(414)
% %     pcolor(x,W.theta*180/pi,ctheta');shading flat;
% %     title('ctheta')
% plot(x,it);colorbar
% title('no. iterations')